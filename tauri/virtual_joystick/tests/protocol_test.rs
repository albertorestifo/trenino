use std::cell::RefCell;
use std::io::{self, BufRead, BufReader, Cursor, Read, Write};
use std::rc::Rc;

use virtual_joystick::protocol::{
    parse_command, serve, Axis, Command, Response, Session, MAX_LINE_BYTES, PROTOCOL_VERSION,
};
use virtual_joystick::vjoy::{AxisRange, DeviceStatus, Report, VJoy, VJoyError};

const RANGE: AxisRange = AxisRange {
    min: 0,
    max: 32_767,
};

#[derive(Clone)]
struct FakeVJoy {
    state: Rc<RefCell<FakeState>>,
}

struct FakeState {
    enabled: Result<bool, VJoyError>,
    status: Result<DeviceStatus, VJoyError>,
    axis_range: Result<AxisRange, VJoyError>,
    axis_range_override: Option<(Axis, AxisRange)>,
    fail_neutral_updates: usize,
    fail_active_updates: usize,
    update_error: Option<VJoyError>,
    relinquish_error: Option<VJoyError>,
    acquire_calls: usize,
    acquired_devices: Vec<u8>,
    relinquish_calls: usize,
    relinquished_devices: Vec<u8>,
    events: Vec<String>,
    reports: Vec<Report>,
}

impl Default for FakeVJoy {
    fn default() -> Self {
        Self {
            state: Rc::new(RefCell::new(FakeState {
                enabled: Ok(true),
                status: Ok(DeviceStatus::Free),
                axis_range: Ok(RANGE),
                axis_range_override: None,
                fail_neutral_updates: 0,
                fail_active_updates: 0,
                update_error: None,
                relinquish_error: None,
                acquire_calls: 0,
                acquired_devices: Vec::new(),
                relinquish_calls: 0,
                relinquished_devices: Vec::new(),
                events: Vec::new(),
                reports: Vec::new(),
            })),
        }
    }
}

impl VJoy for FakeVJoy {
    fn enabled(&mut self) -> Result<bool, VJoyError> {
        self.state.borrow().enabled.clone()
    }

    fn status(&mut self, _device: u8) -> Result<DeviceStatus, VJoyError> {
        self.state.borrow().status.clone()
    }

    fn acquire(&mut self, device: u8) -> Result<(), VJoyError> {
        let mut state = self.state.borrow_mut();
        state.acquire_calls += 1;
        state.acquired_devices.push(device);
        Ok(())
    }

    fn axis_range(&mut self, _device: u8, axis: Axis) -> Result<AxisRange, VJoyError> {
        let state = self.state.borrow();
        if let Some((override_axis, range)) = state.axis_range_override {
            if axis == override_axis {
                return Ok(range);
            }
        }
        state.axis_range.clone()
    }

    fn update(&mut self, _device: u8, report: &Report) -> Result<(), VJoyError> {
        let mut state = self.state.borrow_mut();
        let neutral = Axis::ALL.iter().all(|axis| {
            let range = state
                .axis_range_override
                .filter(|(override_axis, _)| override_axis == axis)
                .map(|(_, range)| range)
                .unwrap_or(RANGE);
            let center =
                (i64::from(range.min) + (i64::from(range.max) - i64::from(range.min)) / 2) as i32;
            report.axis(*axis) == center
        }) && (1..=32).all(|button| !report.button(button));
        state.events.push(if neutral {
            "neutral".into()
        } else {
            "update".into()
        });
        if neutral && state.fail_neutral_updates > 0 {
            state.fail_neutral_updates -= 1;
            return Err(VJoyError::Sdk {
                operation: "UpdateVJD",
                message: "neutral report rejected".into(),
            });
        }
        if !neutral && state.fail_active_updates > 0 {
            state.fail_active_updates -= 1;
            return Err(state.update_error.clone().unwrap_or(VJoyError::Sdk {
                operation: "UpdateVJD",
                message: "active report rejected".into(),
            }));
        }
        if !neutral {
            if let Some(error) = state.update_error.clone() {
                return Err(error);
            }
        }
        state.reports.push(report.clone());
        Ok(())
    }

    fn relinquish(&mut self, device: u8) -> Result<(), VJoyError> {
        let mut state = self.state.borrow_mut();
        state.events.push(format!("relinquish:{device}"));
        state.relinquish_calls += 1;
        state.relinquished_devices.push(device);
        if let Some(error) = state.relinquish_error.clone() {
            return Err(error);
        }
        Ok(())
    }
}

fn ready_session() -> (Session<FakeVJoy>, Rc<RefCell<FakeState>>) {
    let fake = FakeVJoy::default();
    let state = fake.state.clone();
    let mut session = Session::new(fake);
    assert!(matches!(
        session
            .handle_line(r#"{"command":"hello","protocol":1}"#)
            .response,
        Response::Ready { .. }
    ));
    (session, state)
}

#[test]
fn deserializes_each_supported_command() {
    assert_eq!(
        parse_command(r#"{"command":"hello","protocol":1}"#, None).unwrap(),
        Command::Hello {
            protocol: 1,
            device: None,
        }
    );
    assert_eq!(
        parse_command(
            r#"{"command":"set_axis","request_id":7,"device":1,"axis":"slider_2","value":123}"#,
            Some(RANGE),
        )
        .unwrap(),
        Command::SetAxis {
            request_id: 7,
            device: 1,
            axis: Axis::Slider2,
            value: 123,
        }
    );
    assert_eq!(
        parse_command(
            r#"{"command":"set_button","request_id":8,"device":1,"button":32,"pressed":true}"#,
            Some(RANGE),
        )
        .unwrap(),
        Command::SetButton {
            request_id: 8,
            device: 1,
            button: 32,
            pressed: true,
        }
    );
    assert_eq!(
        parse_command(
            r#"{"command":"reset","request_id":9,"device":1}"#,
            Some(RANGE),
        )
        .unwrap(),
        Command::Reset {
            request_id: 9,
            device: 1,
        }
    );
    assert_eq!(
        parse_command(r#"{"command":"shutdown"}"#, Some(RANGE)).unwrap(),
        Command::Shutdown
    );
}

#[test]
fn hello_selects_a_valid_device_and_legacy_hello_defaults_to_device_one() {
    let fake = FakeVJoy::default();
    let state = fake.state.clone();
    let mut selected = Session::new(fake);
    assert_eq!(
        selected
            .handle_line(r#"{"command":"hello","protocol":1,"device":7}"#)
            .response,
        Response::Ready {
            protocol: PROTOCOL_VERSION,
            device: 7,
            axis_min: RANGE.min,
            axis_max: RANGE.max,
        }
    );
    assert_eq!(state.borrow().acquired_devices, [7]);

    let response = selected
        .handle_line(r#"{"command":"set_axis","request_id":1,"device":7,"axis":"x","value":123}"#)
        .response;
    assert_eq!(response, Response::Applied { request_id: 1 });
    assert_eq!(state.borrow().reports.last().unwrap().axis(Axis::X), 123);

    assert!(matches!(
        selected
            .handle_line(
                r#"{"command":"set_axis","request_id":2,"device":1,"axis":"x","value":123}"#
            )
            .response,
        Response::InvalidCommand { .. }
    ));

    let mut legacy = Session::new(FakeVJoy::default());
    assert_eq!(
        legacy
            .handle_line(r#"{"command":"hello","protocol":1}"#)
            .response,
        Response::Ready {
            protocol: PROTOCOL_VERSION,
            device: 1,
            axis_min: RANGE.min,
            axis_max: RANGE.max,
        }
    );
}

#[test]
fn busy_selected_device_is_not_acquired() {
    let fake = FakeVJoy::default();
    fake.state.borrow_mut().status = Ok(DeviceStatus::Busy);
    let state = fake.state.clone();
    let mut session = Session::new(fake);

    assert_eq!(
        session
            .handle_line(r#"{"command":"hello","protocol":1,"device":12}"#)
            .response,
        Response::DeviceBusy { device: 12 }
    );
    assert!(state.borrow().acquired_devices.is_empty());
}

#[test]
fn device_selection_rejects_zero_and_ids_above_sixteen() {
    for device in [0, 17] {
        let mut session = Session::new(FakeVJoy::default());
        let response = session
            .handle_line(&format!(
                r#"{{"command":"hello","protocol":1,"device":{device}}}"#
            ))
            .response;

        assert!(matches!(
            response,
            Response::InvalidCommand {
                code: "invalid_command",
                ..
            }
        ));
    }
}

#[test]
fn each_successful_hello_sends_an_initial_neutral_report() {
    let fake = FakeVJoy::default();
    let state = fake.state.clone();
    let mut session = Session::new(fake);

    assert!(matches!(
        session
            .handle_line(r#"{"command":"hello","protocol":1,"device":9}"#)
            .response,
        Response::Ready { device: 9, .. }
    ));

    let state = state.borrow();
    assert_eq!(state.reports.len(), 1);
    assert!(Axis::ALL
        .iter()
        .all(|axis| state.reports[0].axis(*axis) == 16_383));
    assert!((1..=32).all(|button| !state.reports[0].button(button)));
}

#[test]
fn inconsistent_axis_ranges_relinquish_the_selected_device() {
    let fake = FakeVJoy::default();
    fake.state.borrow_mut().axis_range_override = Some((
        Axis::Slider2,
        AxisRange {
            min: 0,
            max: 65_535,
        },
    ));
    let state = fake.state.clone();
    let mut session = Session::new(fake);

    assert!(matches!(
        session
            .handle_line(r#"{"command":"hello","protocol":1,"device":8}"#)
            .response,
        Response::Error {
            code: "sdk_error",
            ..
        }
    ));
    assert_eq!(state.borrow().relinquished_devices, [8]);
}

#[test]
fn failed_initial_neutral_report_relinquishes_the_selected_device() {
    let fake = FakeVJoy::default();
    fake.state.borrow_mut().fail_neutral_updates = 1;
    let state = fake.state.clone();
    let mut session = Session::new(fake);

    assert!(matches!(
        session
            .handle_line(r#"{"command":"hello","protocol":1,"device":5}"#)
            .response,
        Response::Error {
            code: "sdk_error",
            ..
        }
    ));
    assert_eq!(state.borrow().relinquished_devices, [5]);
    assert_eq!(
        state.borrow().events,
        ["neutral", "neutral", "relinquish:5"]
    );
}

#[test]
fn eof_relinquishes_the_acquired_device() {
    let fake = FakeVJoy::default();
    let state = fake.state.clone();
    let input = Cursor::new(b"{\"command\":\"hello\",\"protocol\":1,\"device\":11}\n".to_vec());
    let mut output = FlushCountingWriter::default();

    serve(input, &mut output, fake).unwrap();

    assert_eq!(state.borrow().relinquished_devices, [11]);
    assert_eq!(
        state.borrow().events,
        ["neutral", "neutral", "relinquish:11"]
    );
}

#[test]
fn a_ready_session_cannot_switch_its_selected_device() {
    let mut session = Session::new(FakeVJoy::default());
    session.handle_line(r#"{"command":"hello","protocol":1,"device":3}"#);

    assert_eq!(
        session
            .handle_line(r#"{"command":"hello","protocol":1,"device":3}"#)
            .response,
        Response::Ready {
            protocol: PROTOCOL_VERSION,
            device: 3,
            axis_min: RANGE.min,
            axis_max: RANGE.max,
        }
    );

    assert!(matches!(
        session
            .handle_line(r#"{"command":"hello","protocol":1,"device":4}"#)
            .response,
        Response::InvalidCommand { .. }
    ));
}

#[test]
fn centered_report_midpoint_handles_the_full_signed_range() {
    let report = Report::centered(AxisRange {
        min: i32::MIN,
        max: i32::MAX,
    });

    assert_eq!(report.axis(Axis::X), -1);
}

#[test]
fn rejects_unsupported_protocol_device_axis_button_and_value() {
    let invalid = [
        (r#"{"command":"hello","protocol":2}"#, None),
        (
            r#"{"command":"set_axis","request_id":1,"device":17,"axis":"x","value":1}"#,
            Some(RANGE),
        ),
        (
            r#"{"command":"set_axis","request_id":1,"device":1,"axis":"pov","value":1}"#,
            Some(RANGE),
        ),
        (
            r#"{"command":"set_button","request_id":1,"device":1,"button":0,"pressed":true}"#,
            Some(RANGE),
        ),
        (
            r#"{"command":"set_button","request_id":1,"device":1,"button":33,"pressed":true}"#,
            Some(RANGE),
        ),
        (
            r#"{"command":"set_axis","request_id":1,"device":1,"axis":"x","value":-1}"#,
            Some(RANGE),
        ),
        (
            r#"{"command":"set_axis","request_id":1,"device":1,"axis":"x","value":32768}"#,
            Some(RANGE),
        ),
    ];

    for (line, range) in invalid {
        assert!(parse_command(line, range).is_err(), "accepted {line}");
    }
}

#[test]
fn serialized_mutation_responses_retain_the_request_id() {
    let (mut session, _) = ready_session();

    for (line, request_id) in [
        (
            r#"{"command":"set_axis","request_id":41,"device":1,"axis":"x","value":1}"#,
            41,
        ),
        (
            r#"{"command":"set_button","request_id":42,"device":1,"button":4,"pressed":true}"#,
            42,
        ),
        (r#"{"command":"reset","request_id":43,"device":1}"#, 43),
    ] {
        let json = serde_json::to_value(session.handle_line(line).response).unwrap();
        assert_eq!(json["request_id"], request_id);
    }
}

#[test]
fn preserves_the_complete_report_across_individual_updates() {
    let (mut session, state) = ready_session();

    session
        .handle_line(r#"{"command":"set_axis","request_id":1,"device":1,"axis":"x","value":1000}"#);
    session.handle_line(
        r#"{"command":"set_button","request_id":2,"device":1,"button":4,"pressed":true}"#,
    );
    session
        .handle_line(r#"{"command":"set_axis","request_id":3,"device":1,"axis":"y","value":2000}"#);

    let state = state.borrow();
    assert_eq!(state.reports.len(), 4);
    let third = &state.reports[3];
    assert_eq!(third.axis(Axis::X), 1000);
    assert_eq!(third.axis(Axis::Y), 2000);
    assert!(third.button(4));
}

#[test]
fn reset_centers_every_axis_and_releases_every_button() {
    let (mut session, state) = ready_session();
    session.handle_line(
        r#"{"command":"set_axis","request_id":1,"device":1,"axis":"rz","value":3000}"#,
    );
    session.handle_line(
        r#"{"command":"set_button","request_id":2,"device":1,"button":32,"pressed":true}"#,
    );
    let response = session
        .handle_line(r#"{"command":"reset","request_id":3,"device":1}"#)
        .response;

    assert_eq!(response, Response::Applied { request_id: 3 });
    let state = state.borrow();
    let reset = state.reports.last().unwrap();
    for axis in Axis::ALL {
        assert_eq!(reset.axis(axis), 16_383);
    }
    for button in 1..=32 {
        assert!(!reset.button(button));
    }
}

#[test]
fn shutdown_relinquishes_the_device_and_stops_the_server() {
    let (mut session, state) = ready_session();
    let result = session.handle_line(r#"{"command":"shutdown"}"#);

    assert_eq!(result.response, Response::Stopped);
    assert!(result.shutdown);
    assert_eq!(state.borrow().relinquish_calls, 1);
    assert_eq!(
        state.borrow().events,
        ["neutral", "neutral", "relinquish:1"]
    );
}

#[test]
fn nonneutral_shutdown_neutralizes_before_releasing_selected_device_once() {
    let fake = FakeVJoy::default();
    let state = fake.state.clone();
    let mut session = Session::new(fake);
    session.handle_line(r#"{"command":"hello","protocol":1,"device":16}"#);
    session.handle_line(
        r#"{"command":"set_button","request_id":1,"device":16,"button":32,"pressed":true}"#,
    );

    let result = session.handle_line(r#"{"command":"shutdown"}"#);
    assert_eq!(result.response, Response::Stopped);
    assert!(result.shutdown);
    assert_eq!(
        state.borrow().events,
        ["neutral", "update", "neutral", "relinquish:16"]
    );
    assert_eq!(state.borrow().relinquish_calls, 1);
    assert!(state.borrow().reports.last().unwrap().button(32) == false);
}

#[test]
fn shutdown_reports_neutralize_and_relinquish_failures_but_still_releases_once() {
    let fake = FakeVJoy::default();
    let state = fake.state.clone();
    let mut session = Session::new(fake);
    session.handle_line(r#"{"command":"hello","protocol":1,"device":12}"#);
    session.handle_line(
        r#"{"command":"set_button","request_id":1,"device":12,"button":2,"pressed":true}"#,
    );
    {
        let mut state = state.borrow_mut();
        state.fail_neutral_updates = 1;
        state.relinquish_error = Some(VJoyError::Sdk {
            operation: "RelinquishVJD",
            message: "failed".into(),
        });
    }

    let result = session.handle_line(r#"{"command":"shutdown"}"#);
    assert!(result.shutdown);
    assert!(matches!(
        result.response,
        Response::Error {
            code: "shutdown_failed",
            message,
            request_id: None,
        } if message.contains("neutral report rejected") && message.contains("RelinquishVJD")
    ));
    assert_eq!(
        state.borrow().events,
        ["neutral", "update", "neutral", "relinquish:12"]
    );
    assert_eq!(state.borrow().relinquish_calls, 1);
}

#[test]
fn cleanup_uses_verified_ranges_if_later_range_queries_fail() {
    let (mut session, state) = ready_session();
    session.handle_line(
        r#"{"command":"set_button","request_id":1,"device":1,"button":1,"pressed":true}"#,
    );
    state.borrow_mut().axis_range = Err(VJoyError::Sdk {
        operation: "GetVJDAxisMin/GetVJDAxisMax",
        message: "temporary query failure".into(),
    });

    assert_eq!(
        session.handle_line(r#"{"command":"shutdown"}"#).response,
        Response::Stopped
    );
    assert_eq!(
        state.borrow().events,
        ["neutral", "update", "neutral", "relinquish:1"]
    );
}

#[test]
fn direct_session_drop_neutralizes_then_relinquishes_once() {
    let fake = FakeVJoy::default();
    let state = fake.state.clone();
    let mut session = Session::new(fake);
    session.handle_line(r#"{"command":"hello","protocol":1,"device":14}"#);
    session
        .handle_line(r#"{"command":"set_axis","request_id":1,"device":14,"axis":"x","value":12}"#);
    drop(session);

    assert_eq!(
        state.borrow().events,
        ["neutral", "update", "neutral", "relinquish:14"]
    );
    assert_eq!(state.borrow().relinquish_calls, 1);
}

#[test]
fn busy_device_is_rejected_without_an_acquisition_attempt() {
    let fake = FakeVJoy::default();
    fake.state.borrow_mut().status = Ok(DeviceStatus::Busy);
    let state = fake.state.clone();
    let mut session = Session::new(fake);

    let response = session
        .handle_line(r#"{"command":"hello","protocol":1}"#)
        .response;

    assert_eq!(response, Response::DeviceBusy { device: 1 });
    assert_eq!(state.borrow().acquire_calls, 0);
}

#[test]
fn reset_before_hello_returns_not_ready_without_panicking() {
    let fake = FakeVJoy::default();
    let mut session = Session::new(fake);

    let response = session
        .handle_line(r#"{"command":"reset","request_id":51,"device":1}"#)
        .response;

    assert_eq!(
        response,
        Response::Error {
            code: "not_ready",
            message: "send hello before updating controls".to_string(),
            request_id: Some(51),
        }
    );
}

#[test]
fn axis_range_failure_after_acquire_relinquishes_the_device() {
    let fake = FakeVJoy::default();
    fake.state.borrow_mut().axis_range = Err(VJoyError::Sdk {
        operation: "GetVJDAxisMin/GetVJDAxisMax",
        message: "call returned false".to_string(),
    });
    let state = fake.state.clone();
    let mut session = Session::new(fake);

    let response = session
        .handle_line(r#"{"command":"hello","protocol":1}"#)
        .response;

    assert!(matches!(
        response,
        Response::Error {
            code: "cleanup_failed",
            ..
        }
    ));
    assert_eq!(state.borrow().acquire_calls, 1);
    assert_eq!(state.borrow().relinquish_calls, 1);
    assert_eq!(state.borrow().events, ["relinquish:1"]);
}

#[test]
fn device_removal_is_translated_and_keeps_the_request_id() {
    let (mut session, state) = ready_session();
    state.borrow_mut().update_error = Some(VJoyError::DeviceRemoved);

    let response = session
        .handle_line(r#"{"command":"set_axis","request_id":77,"device":1,"axis":"x","value":100}"#)
        .response;

    assert_eq!(
        response,
        Response::DeviceRemoved {
            device: 1,
            request_id: Some(77),
        }
    );
    assert_eq!(state.borrow().relinquished_devices, [1]);
    assert_eq!(
        session
            .handle_line(
                r#"{"command":"set_axis","request_id":78,"device":1,"axis":"x","value":101}"#
            )
            .response,
        Response::InvalidCommand {
            code: "invalid_command",
            message: "send hello before setting axes".into(),
            request_id: Some(78),
        }
    );
}

#[test]
fn failed_device_update_relinquishes_its_explicit_selection() {
    let fake = FakeVJoy::default();
    let state = fake.state.clone();
    let mut session = Session::new(fake);
    session.handle_line(r#"{"command":"hello","protocol":1,"device":13}"#);
    state.borrow_mut().update_error = Some(VJoyError::Sdk {
        operation: "UpdateVJD",
        message: "call returned false".into(),
    });

    assert!(matches!(
        session
            .handle_line(
                r#"{"command":"set_axis","request_id":79,"device":13,"axis":"x","value":101}"#
            )
            .response,
        Response::Error {
            code: "sdk_error",
            request_id: Some(79),
            ..
        }
    ));
    assert_eq!(state.borrow().relinquished_devices, [13]);
    assert_eq!(
        state.borrow().events,
        ["neutral", "update", "neutral", "relinquish:13"]
    );
    let response = session
        .handle_line(r#"{"command":"set_axis","request_id":80,"device":13,"axis":"x","value":102}"#)
        .response;
    assert!(matches!(
        response,
        Response::InvalidCommand {
            code: "invalid_command",
            message,
            request_id: Some(80),
        } if message == "send hello before setting axes"
    ));
}

#[test]
fn sdk_errors_are_translated_to_structured_protocol_errors() {
    let (mut session, state) = ready_session();
    state.borrow_mut().update_error = Some(VJoyError::Sdk {
        operation: "UpdateVJD",
        message: "call returned false".to_string(),
    });

    let json = serde_json::to_value(
        session
            .handle_line(
                r#"{"command":"set_button","request_id":88,"device":1,"button":2,"pressed":true}"#,
            )
            .response,
    )
    .unwrap();

    assert_eq!(json["event"], "error");
    assert_eq!(json["code"], "sdk_error");
    assert_eq!(json["request_id"], 88);
    assert!(json["message"].as_str().unwrap().contains("UpdateVJD"));
}

#[test]
fn malformed_and_oversized_lines_return_errors_then_recover() {
    let fake = FakeVJoy::default();
    let input = format!(
        "not-json\n{}\n{{\"command\":\"hello\",\"protocol\":{PROTOCOL_VERSION}}}\n{{\"command\":\"shutdown\"}}\n",
        "x".repeat(MAX_LINE_BYTES + 1)
    );
    let mut output = FlushCountingWriter::default();

    serve(Cursor::new(input.into_bytes()), &mut output, fake).unwrap();

    let lines: Vec<serde_json::Value> = String::from_utf8(output.bytes)
        .unwrap()
        .lines()
        .map(|line| serde_json::from_str(line).unwrap())
        .collect();
    assert_eq!(lines.len(), 4);
    assert_eq!(lines[0]["event"], "invalid_command");
    assert_eq!(lines[1]["code"], "input_too_large");
    assert_eq!(lines[2]["event"], "ready");
    assert_eq!(lines[3]["event"], "stopped");
    assert_eq!(output.flushes, 4);
}

#[test]
fn chunked_oversized_line_is_drained_then_next_command_is_processed() {
    let fake = FakeVJoy::default();
    let input = format!(
        "{}\n{{\"command\":\"hello\",\"protocol\":{PROTOCOL_VERSION}}}\n{{\"command\":\"shutdown\"}}\n",
        "x".repeat(MAX_LINE_BYTES + 4096)
    );
    let reader = ChunkedReader::new(input.into_bytes(), 37);
    let mut output = FlushCountingWriter::default();

    serve(reader, &mut output, fake).unwrap();

    let lines: Vec<serde_json::Value> = String::from_utf8(output.bytes)
        .unwrap()
        .lines()
        .map(|line| serde_json::from_str(line).unwrap())
        .collect();
    assert_eq!(lines.len(), 3);
    assert_eq!(lines[0]["code"], "input_too_large");
    assert_eq!(lines[1]["event"], "ready");
    assert_eq!(lines[2]["event"], "stopped");
}

#[test]
fn oversized_unterminated_line_emits_one_error_at_eof() {
    let fake = FakeVJoy::default();
    let reader = ChunkedReader::new(vec![b'x'; MAX_LINE_BYTES + 4096], 29);
    let mut output = FlushCountingWriter::default();

    serve(reader, &mut output, fake).unwrap();

    let lines: Vec<serde_json::Value> = String::from_utf8(output.bytes)
        .unwrap()
        .lines()
        .map(|line| serde_json::from_str(line).unwrap())
        .collect();
    assert_eq!(lines.len(), 1);
    assert_eq!(lines[0]["code"], "input_too_large");
}

#[test]
fn accepts_exact_limit_and_crlf_lines_and_rejects_invalid_utf8() {
    let hello = format!(r#"{{"command":"hello","protocol":{PROTOCOL_VERSION}}}"#);
    let mut input = hello.clone();
    input.push_str(&" ".repeat(MAX_LINE_BYTES - hello.len()));
    input.push('\n');
    input.push_str(&hello);
    input.push_str("\r\n");
    let mut input = input.into_bytes();
    input.extend_from_slice(&[0xFF, b'\n']);
    input.extend_from_slice(b"{\"command\":\"shutdown\"}\n");

    let fake = FakeVJoy::default();
    let mut output = FlushCountingWriter::default();
    serve(Cursor::new(input), &mut output, fake).unwrap();

    let lines: Vec<serde_json::Value> = String::from_utf8(output.bytes)
        .unwrap()
        .lines()
        .map(|line| serde_json::from_str(line).unwrap())
        .collect();
    assert_eq!(lines.len(), 4);
    assert_eq!(lines[0]["event"], "ready");
    assert_eq!(lines[1]["event"], "ready");
    assert_eq!(lines[2]["event"], "invalid_command");
    assert_eq!(lines[3]["event"], "stopped");
}

#[test]
fn input_error_after_acquisition_still_neutralizes_and_releases() {
    let fake = FakeVJoy::default();
    let state = fake.state.clone();
    let input = BufReader::new(ErrorAfterLine::new(
        b"{\"command\":\"hello\",\"protocol\":1,\"device\":15}\n".to_vec(),
    ));
    let mut output = FlushCountingWriter::default();

    assert!(serve(input, &mut output, fake).is_err());
    assert_eq!(
        state.borrow().events,
        ["neutral", "neutral", "relinquish:15"]
    );
    assert_eq!(state.borrow().relinquish_calls, 1);
}

#[test]
fn output_write_and_flush_errors_after_acquisition_still_clean_up() {
    for fail_flush in [false, true] {
        let fake = FakeVJoy::default();
        let state = fake.state.clone();
        let input = Cursor::new(b"{\"command\":\"hello\",\"protocol\":1,\"device\":10}\n".to_vec());
        let mut output = FailingWriter::new(!fail_flush, fail_flush);

        assert!(serve(input, &mut output, fake).is_err());
        assert_eq!(
            state.borrow().events,
            ["neutral", "neutral", "relinquish:10"]
        );
        assert_eq!(state.borrow().relinquish_calls, 1);
    }
}

struct ChunkedReader {
    cursor: Cursor<Vec<u8>>,
    chunk_size: usize,
}

struct ErrorAfterLine {
    bytes: Cursor<Vec<u8>>,
    emitted_error: bool,
}

impl ErrorAfterLine {
    fn new(bytes: Vec<u8>) -> Self {
        Self {
            bytes: Cursor::new(bytes),
            emitted_error: false,
        }
    }
}

impl Read for ErrorAfterLine {
    fn read(&mut self, buffer: &mut [u8]) -> io::Result<usize> {
        if self.bytes.position() < self.bytes.get_ref().len() as u64 {
            return self.bytes.read(buffer);
        }
        self.emitted_error = true;
        Err(io::Error::new(
            io::ErrorKind::Other,
            "injected read failure",
        ))
    }
}

struct FailingWriter {
    fail_write: bool,
    fail_flush: bool,
}

impl FailingWriter {
    fn new(fail_write: bool, fail_flush: bool) -> Self {
        Self {
            fail_write,
            fail_flush,
        }
    }
}

impl Write for FailingWriter {
    fn write(&mut self, buf: &[u8]) -> io::Result<usize> {
        if self.fail_write {
            return Err(io::Error::new(
                io::ErrorKind::Other,
                "injected write failure",
            ));
        }
        Ok(buf.len())
    }

    fn flush(&mut self) -> io::Result<()> {
        if self.fail_flush {
            Err(io::Error::new(
                io::ErrorKind::Other,
                "injected flush failure",
            ))
        } else {
            Ok(())
        }
    }
}

impl ChunkedReader {
    fn new(bytes: Vec<u8>, chunk_size: usize) -> Self {
        Self {
            cursor: Cursor::new(bytes),
            chunk_size,
        }
    }
}

impl Read for ChunkedReader {
    fn read(&mut self, buffer: &mut [u8]) -> io::Result<usize> {
        let limit = buffer.len().min(self.chunk_size);
        self.cursor.read(&mut buffer[..limit])
    }
}

impl BufRead for ChunkedReader {
    fn fill_buf(&mut self) -> io::Result<&[u8]> {
        let remaining = self.cursor.fill_buf()?;
        Ok(&remaining[..remaining.len().min(self.chunk_size)])
    }

    fn consume(&mut self, amount: usize) {
        self.cursor.consume(amount);
    }
}

#[derive(Default)]
struct FlushCountingWriter {
    bytes: Vec<u8>,
    flushes: usize,
}

impl Write for FlushCountingWriter {
    fn write(&mut self, buf: &[u8]) -> io::Result<usize> {
        self.bytes.extend_from_slice(buf);
        Ok(buf.len())
    }

    fn flush(&mut self) -> io::Result<()> {
        self.flushes += 1;
        Ok(())
    }
}
