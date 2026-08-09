pub mod protocol;
pub mod vjoy;

use std::path::{Path, PathBuf};

pub fn vjoy_interface_path<I, S>(arguments: I) -> Result<PathBuf, &'static str>
where
    I: IntoIterator<Item = S>,
    S: AsRef<std::ffi::OsStr>,
{
    let arguments: Vec<PathBuf> = arguments
        .into_iter()
        .map(|argument| PathBuf::from(argument.as_ref()))
        .collect();
    if arguments.len() != 4
        || arguments[1] != Path::new("serve")
        || arguments[2] != Path::new("--vjoy-interface")
    {
        return Err("usage: virtual_joystick serve --vjoy-interface <absolute path>");
    }

    let path = &arguments[3];
    let expected_name = path
        .file_name()
        .and_then(|name| name.to_str())
        .is_some_and(|name| name.eq_ignore_ascii_case("vJoyInterface.dll"));

    if !path.is_absolute() || !expected_name {
        return Err("vJoy interface must be an absolute path to vJoyInterface.dll");
    }

    Ok(path.clone())
}
