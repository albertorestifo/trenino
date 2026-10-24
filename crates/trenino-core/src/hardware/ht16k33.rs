pub fn segment14(c: char) -> [u8; 2] {
    match c as u32 {
        0x20 => [0, 0],
        0x21 => [6, 32],
        0x22 => [32, 32],
        0x23 => [206, 18],
        0x24 => [237, 18],
        0x25 => [36, 12],
        0x26 => [155, 1],
        0x27 => [0, 2],
        0x28 => [0, 12],
        0x29 => [0, 33],
        0x2a => [192, 63],
        0x2b => [192, 18],
        0x2c => [0, 32],
        0x2d => [192, 0],
        0x2e => [0, 64],
        0x2f => [0, 12],
        0x30 => [63, 18],
        0x31 => [6, 0],
        0x32 => [219, 0],
        0x33 => [207, 0],
        0x34 => [230, 0],
        0x35 => [237, 0],
        0x36 => [253, 0],
        0x37 => [7, 18],
        0x38 => [255, 0],
        0x39 => [239, 0],
        0x3a => [0, 18],
        0x3b => [0, 34],
        0x3c => [0, 12],
        0x3d => [200, 0],
        0x3e => [0, 33],
        0x3f => [131, 16],
        0x40 => [187, 2],
        0x41 => [247, 0],
        0x42 => [143, 18],
        0x43 => [57, 0],
        0x44 => [15, 18],
        0x45 => [249, 0],
        0x46 => [241, 0],
        0x47 => [189, 0],
        0x48 => [246, 0],
        0x49 => [0, 18],
        0x4a => [30, 0],
        0x4b => [112, 12],
        0x4c => [56, 0],
        0x4d => [54, 5],
        0x4e => [54, 9],
        0x4f => [63, 0],
        0x50 => [243, 0],
        0x51 => [63, 8],
        0x52 => [243, 8],
        0x53 => [237, 0],
        0x54 => [1, 18],
        0x55 => [62, 0],
        0x56 => [48, 6],
        0x57 => [54, 40],
        0x58 => [0, 45],
        0x59 => [0, 21],
        0x5a => [9, 12],
        0x5b => [57, 0],
        0x5c => [0, 9],
        0x5d => [15, 0],
        0x5e => [0, 6],
        0x5f => [8, 0],
        0x60 => [0, 2],
        0x61 => [251, 0],
        0x62 => [248, 0],
        0x63 => [216, 0],
        0x64 => [222, 0],
        0x65 => [251, 0],
        0x66 => [241, 0],
        0x67 => [239, 0],
        0x68 => [244, 0],
        0x69 => [0, 16],
        0x6a => [14, 0],
        0x6b => [112, 12],
        0x6c => [48, 0],
        0x6d => [212, 0],
        0x6e => [212, 0],
        0x6f => [220, 0],
        0x70 => [243, 0],
        0x71 => [231, 0],
        0x72 => [208, 0],
        0x73 => [237, 0],
        0x74 => [248, 0],
        0x75 => [28, 0],
        0x76 => [48, 6],
        0x77 => [54, 40],
        0x78 => [0, 45],
        0x79 => [0, 21],
        0x7a => [9, 12],
        _ => [0, 0],
    }
}
pub fn segment7(c: char) -> u8 {
    match c as u32 {
        0x20 => 0,
        0x2d => 64,
        0x30 => 63,
        0x31 => 6,
        0x32 => 91,
        0x33 => 79,
        0x34 => 102,
        0x35 => 109,
        0x36 => 125,
        0x37 => 7,
        0x38 => 127,
        0x39 => 111,
        0x41 => 119,
        0x42 => 124,
        0x43 => 57,
        0x44 => 94,
        0x45 => 121,
        0x46 => 113,
        0x48 => 118,
        0x4c => 56,
        0x4f => 63,
        0x50 => 115,
        0x55 => 62,
        0x61 => 119,
        0x62 => 124,
        0x63 => 88,
        0x64 => 94,
        0x65 => 123,
        0x66 => 113,
        0x68 => 116,
        0x6c => 48,
        0x6e => 84,
        0x6f => 92,
        0x72 => 80,
        0x74 => 120,
        0x75 => 28,
        _ => 0,
    }
}
pub fn encode_string(
    text: &str,
    digits: usize,
    seven_segment: bool,
    has_dot: bool,
    align_right: bool,
) -> Vec<u8> {
    use unicode_segmentation::UnicodeSegmentation;
    let mut chars: Vec<char> = text.chars().collect();
    if align_right {
        let graphemes: Vec<&str> = text.graphemes(true).collect();
        let dots = if has_dot {
            graphemes.iter().filter(|g| **g == ".").count()
        } else {
            0
        };
        let slots = graphemes.len().saturating_sub(dots);
        if slots < digits {
            let mut p = vec![' '; digits - slots];
            p.append(&mut chars);
            chars = p;
        }
    }
    if seven_segment {
        let mut out = Vec::new();
        let mut remaining = digits;
        for c in chars {
            if remaining == 0 {
                break;
            }
            if c == '.' {
                if has_dot {
                    if let Some(x) = out.last_mut() {
                        *x |= 128
                    } else {
                        out.push(128);
                        remaining -= 1
                    }
                }
                continue;
            }
            out.push(segment7(c));
            remaining -= 1;
        }
        out.resize(digits, 0);
        out
    } else {
        let mut out = Vec::new();
        for c in chars.into_iter().take(digits) {
            out.extend(segment14(c));
        }
        out.resize(digits * 2, 0);
        out
    }
}
