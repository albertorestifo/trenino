use std::path::Path;
use virtual_joystick::vjoy_interface_path;

#[test]
fn requires_an_absolute_vjoy_interface_dll_path() {
    let dll = std::env::current_dir().unwrap().join("vJoyInterface.dll");
    let args = vec![
        "virtual_joystick".to_string(),
        "serve".to_string(),
        "--vjoy-interface".to_string(),
        dll.to_string_lossy().into_owned(),
    ];
    assert_eq!(vjoy_interface_path(args).unwrap(), Path::new(&dll));

    assert!(vjoy_interface_path([
        "virtual_joystick",
        "serve",
        "--vjoy-interface",
        "vJoyInterface.dll",
    ])
    .is_err());
    assert!(vjoy_interface_path(["virtual_joystick", "serve"]).is_err());
}

#[test]
fn rejects_a_different_dll_name_or_extra_arguments() {
    assert!(vjoy_interface_path([
        "virtual_joystick",
        "serve",
        "--vjoy-interface",
        r"C:\Windows\System32\other.dll",
    ])
    .is_err());
    assert!(vjoy_interface_path([
        "virtual_joystick",
        "serve",
        "--vjoy-interface",
        r"C:\Program Files\Trenino\resources\vJoyInterface.dll",
        "unexpected",
    ])
    .is_err());
}
