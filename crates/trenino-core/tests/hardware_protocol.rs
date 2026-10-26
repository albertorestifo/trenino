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
    let ht16k33 = Message::ConfigureHt16k33 {
        config_id: 0,
        total_parts: 1,
        part_number: 0,
        address: 0x70,
        brightness: 8,
        num_digits: 4,
    };
    let bytes = vec![2, 0, 0, 0, 0, 1, 0, 4, 0x70, 8, 4];
    assert_eq!(encode_message(&ht16k33).unwrap(), bytes);
    assert_eq!(decode_message(&bytes).unwrap(), ht16k33);
    // Exact length is enforced for the HT16K33 subtype like the others.
    assert!(decode_message(&[2, 0, 0, 0, 0, 1, 0, 4, 0x70, 8]).is_err());
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
#[test]
fn configure_builder_has_exact_golden_wire_packets() {
    use trenino_core::hardware::{
        build_configuration, AnalogInput, ButtonInput, ConfigId, DeviceConfiguration, Matrix,
        Module,
    };
    let configuration = DeviceConfiguration {
        inputs: vec![
            ButtonInput {
                pin: 2,
                debounce: 4,
            }
            .into(),
            AnalogInput {
                pin: 1,
                sensitivity: 10,
            }
            .into(),
        ],
        matrices: vec![Matrix {
            row_pins: vec![3],
            col_pins: vec![4],
        }],
        modules: vec![Module::Ht16k33 {
            address: 112,
            brightness: 8,
            num_digits: 4,
        }],
    };
    let messages = build_configuration(&configuration, ConfigId::new(77).unwrap()).unwrap();
    let golden = [
        vec![2, 77, 0, 0, 0, 4, 0, 0, 1, 10],
        vec![2, 77, 0, 0, 0, 4, 1, 1, 2, 4],
        vec![2, 77, 0, 0, 0, 4, 2, 2, 1, 1, 3, 4],
        vec![2, 77, 0, 0, 0, 4, 3, 4, 112, 8, 4],
    ];
    assert_eq!(
        messages
            .iter()
            .map(|m| trenino_core::hardware::protocol::encode_message(m).unwrap())
            .collect::<Vec<_>>(),
        golden
    );
}

#[test]
fn framing_handles_coalesced_empty_delimiters_and_malformed_recovery() {
    let first = FrameDecoder::encode_frame(&[1, 2]);
    let second = FrameDecoder::encode_frame(&[3, 0, 4]);
    let wire = [vec![0, 0, 0xff, 0xaa, 0xbb, 0, 0], first, vec![0], second].concat();
    let mut decoder = FrameDecoder::default();
    let mut outcomes = Vec::new();
    for chunk in wire.chunks(3) {
        outcomes.extend(decoder.push(chunk));
    }
    assert_eq!(outcomes.len(), 3);
    assert!(outcomes[0].is_err());
    assert_eq!(outcomes[1], Ok(vec![1, 2]));
    assert_eq!(outcomes[2], Ok(vec![3, 0, 4]));
}
#[test]
fn every_two_chunk_split_decodes_the_same_coalesced_stream() {
    let a = FrameDecoder::encode_frame(&[0x11, 0, 0x22]);
    let b = FrameDecoder::encode_frame(&[0x33, 0x44]);
    let joined = [a, b].concat();
    for split in 0..=joined.len() {
        let mut decoder = FrameDecoder::default();
        let mut out = decoder.push(&joined[..split]);
        out.extend(decoder.push(&joined[split..]));
        assert_eq!(
            out,
            vec![Ok(vec![0x11, 0, 0x22]), Ok(vec![0x33, 0x44])],
            "split at {split}"
        );
    }
}

#[test]
fn oversized_unterminated_frame_is_bounded_and_decoder_resynchronizes() {
    let matrix = Message::ConfigureMatrix {
        config_id: 7,
        total_parts: 1,
        part_number: 0,
        row_pins: vec![1; 255],
        col_pins: vec![2; 255],
    };
    let payload = encode_message(&matrix).unwrap();
    assert_eq!(payload.len(), 520);
    let frame = FrameDecoder::encode_frame(&payload);
    assert_eq!(frame.len(), 524); // 523 encoded bytes plus the delimiter
    let mut decoder = FrameDecoder::default();
    assert_eq!(decoder.push(&frame), vec![Ok(payload)]);
    assert_eq!(
        decode_message(&encode_message(&matrix).unwrap()),
        Ok(matrix)
    );

    let too_long = vec![0x55; 524];
    let outcomes = decoder.push(&too_long);
    assert_eq!(outcomes.len(), 1);
    assert!(outcomes[0].is_err());
    let recovery = FrameDecoder::encode_frame(&[6]);
    assert_eq!(
        decoder.push(&[&too_long[..0], &[0], &recovery].concat()),
        vec![Ok(vec![6])]
    );
}
