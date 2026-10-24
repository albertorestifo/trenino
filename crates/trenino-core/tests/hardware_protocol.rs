use trenino_core::hardware::protocol::{decode_message, encode_message, FrameDecoder, Message};

#[test]
fn message_bytes_match_firmware_contract() {
    let cases = [
        (
            Message::IdentityRequest {
                request_id: 0x12345678,
            },
            vec![0x00, 0x78, 0x56, 0x34, 0x12],
        ),
        (
            Message::IdentityResponse {
                request_id: 0x12345678,
                major: 1,
                minor: 2,
                patch: 3,
                config_id: 0xdeadbeef,
            },
            vec![1, 0x78, 0x56, 0x34, 0x12, 1, 2, 3, 0xef, 0xbe, 0xad, 0xde],
        ),
        (
            Message::ConfigurationStored {
                config_id: 0x12345678,
            },
            vec![3, 0x78, 0x56, 0x34, 0x12],
        ),
        (
            Message::ConfigurationError {
                config_id: 0x12345678,
            },
            vec![4, 0x78, 0x56, 0x34, 0x12],
        ),
        (
            Message::InputValue { pin: 10, value: -1 },
            vec![5, 10, 0xff, 0xff],
        ),
        (Message::Heartbeat, vec![6]),
        (Message::SetOutput { pin: 5, high: true }, vec![7, 5, 1]),
        (Message::RetryCalibration { pin: 255 }, vec![8, 255]),
        (
            Message::WriteSegments {
                address: 0x70,
                data: vec![0xaa, 0x55],
            },
            vec![13, 0x70, 2, 0xaa, 0x55],
        ),
        (
            Message::SetModuleBrightness {
                address: 0x71,
                brightness: 15,
            },
            vec![14, 0x71, 15],
        ),
        (
            Message::ModuleError {
                address: 0x72,
                error_code: 3,
            },
            vec![15, 0x72, 3],
        ),
    ];
    for (message, expected) in cases {
        assert_eq!(encode_message(&message).unwrap(), expected);
        assert_eq!(decode_message(&expected).unwrap(), message);
    }
}

#[test]
fn configure_payloads_roundtrip_and_reserved_types_rejected() {
    let m = Message::ConfigureMatrix {
        config_id: 7,
        total_parts: 2,
        part_number: 1,
        row_pins: vec![2, 3],
        col_pins: vec![8],
    };
    let bytes = vec![2, 7, 0, 0, 0, 2, 1, 2, 2, 1, 2, 3, 8];
    assert_eq!(encode_message(&m).unwrap(), bytes);
    assert_eq!(decode_message(&bytes).unwrap(), m);
    assert!(decode_message(&[9]).is_err());
    assert!(decode_message(&[2, 0, 0, 0, 0, 1, 0, 4, 0x70, 8, 4]).is_err()); // firmware has no HT16K33 decode arm
}

#[test]
fn framing_preserves_custom_trailing_zero_and_recovers_after_bad_frame() {
    let payload = [0x11, 0, 0x22];
    let frame = FrameDecoder::encode_frame(&payload);
    assert_eq!(frame, vec![2, 0x11, 2, 0x22, 0]);
    let mut d = FrameDecoder::default();
    assert!(d.push(&[0xff, 0xaa, 0xbb, 0]).first().unwrap().is_err());
    assert_eq!(d.push(&frame), vec![Ok(payload.to_vec())]);
}

#[test]
fn framing_handles_fragmented_and_254_byte_boundary() {
    let p = vec![0xaa; 254];
    let f = FrameDecoder::encode_frame(&p);
    assert_eq!(f.len(), 257);
    assert_eq!(&f[..1], &[0xff]);
    assert_eq!(&f[255..], &[1, 0]);
    let mut d = FrameDecoder::default();
    assert!(d.push(&f[..17]).is_empty());
    assert_eq!(d.push(&f[17..]), vec![Ok(p)]);
}
