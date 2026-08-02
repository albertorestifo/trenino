use std::cell::RefCell;
use std::io::{self, Cursor, Write};
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
    update_error: Option<VJoyError>,
    acquire_calls: usize,
    relinquish_calls: usize,
    reports: Vec<Report>,
}

impl Default for FakeVJoy {
    fn default() -> Self {
        Self {
            state: Rc::new(RefCell::new(FakeState {
                enabled: Ok(true),
                status: Ok(DeviceStatus::Free),
                axis_range: Ok(RANGE),
                update_error: None,
                acquire_calls: 0,
                relinquish_calls: 0,
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

    fn acquire(&mut self, _device: u8) -> Result<(), VJoyError> {
        self.state.borrow_mut().acquire_calls += 1;
        Ok(())
    }

    fn axis_range(&mut self, _device: u8, _axis: Axis) -> Result<AxisRange, VJoyError> {
        self.state.borrow().axis_range.clone()
    }

    fn update(&mut self, _device: u8, report: &Report) -> Result<(), VJoyError> {
        let mut state = self.state.borrow_mut();
        if let Some(error) = state.update_error.clone() {
            return Err(error);
        }
        state.reports.push(report.clone());
        Ok(())
    }

    fn relinquish(&mut self, _device: u8) {
        self.state.borrow_mut().relinquish_calls += 1;
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
        Command::Hello { protocol: 1 }
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
fn rejects_unsupported_protocol_device_axis_button_and_value() {
    let invalid = [
        (r#"{"command":"hello","protocol":2}"#, None),
        (
            r#"{"command":"set_axis","request_id":1,"device":2,"axis":"x","value":1}"#,
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
    assert_eq!(state.reports.len(), 3);
    let third = &state.reports[2];
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
