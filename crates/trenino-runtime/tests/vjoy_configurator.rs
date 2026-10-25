//! Portable configurator contract against the Elixir create/delete/trust oracle.
use std::collections::{HashMap, VecDeque};
use std::path::{Path, PathBuf};

use trenino_runtime::vjoy::configurator::{
    broker_request, create_arguments, marker_name, run_bounded, trusted_resource, BoundedProcess,
    ConfigStatus, Configurator, ConfiguratorBackend, ConfiguratorError, FileKind, FileProbe,
    ProcessOutput, ResourcePaths,
};

#[test]
fn privileged_broker_accepts_only_exact_selected_id_operations() {
    assert_eq!(broker_request(&create_arguments(7)), Ok(("create", 7)));
    assert_eq!(
        broker_request(&["-d".into(), "7".into()]),
        Ok(("delete", 7))
    );
    for args in [
        vec!["-d".into(), "0".into()],
        vec!["7".into(), "-a".into()],
        vec!["-d".into(), "7".into(), "8".into()],
    ] {
        assert_eq!(broker_request(&args), Err(ConfiguratorError::InvalidDevice));
    }
}

struct FakeSystem {
    files: HashMap<PathBuf, FileKind>,
    statuses: VecDeque<ConfigStatus>,
    last_status: ConfigStatus,
    now: u64,
    status_cost: u64,
    consent_cost: u64,
    helper_cost: u64,
    elevate_result: Result<i32, ConfiguratorError>,
    marker: [bool; 17],
    pending: [bool; 17],
    confirmed: [bool; 17],
    marker_write_fails: bool,
    cleanup_incomplete: bool,
    calls: Vec<String>,
}

impl Default for FakeSystem {
    fn default() -> Self {
        Self {
            files: HashMap::new(),
            statuses: VecDeque::new(),
            last_status: ConfigStatus::DriverMissing,
            now: 0,
            status_cost: 0,
            consent_cost: 0,
            helper_cost: 0,
            elevate_result: Ok(0),
            marker: [false; 17],
            pending: [false; 17],
            confirmed: [false; 17],
            marker_write_fails: false,
            cleanup_incomplete: false,
            calls: Vec::new(),
        }
    }
}

impl FakeSystem {
    fn installed() -> (Self, ResourcePaths) {
        let anchor = PathBuf::from("/installed/Trenino");
        let resources = anchor.join("resources");
        let mut system = Self {
            elevate_result: Ok(0),
            ..Self::default()
        };
        system.files.insert(PathBuf::from("/"), FileKind::Directory);
        system
            .files
            .insert(PathBuf::from("/installed"), FileKind::Directory);
        system.files.insert(anchor.clone(), FileKind::Directory);
        system.files.insert(resources.clone(), FileKind::Directory);
        for name in ["vJoyConfig.exe", "vJoyInstall.dll", "vJoyInterface.dll"] {
            system.files.insert(resources.join(name), FileKind::Regular);
        }
        (system, ResourcePaths { anchor, resources })
    }
}

impl FileProbe for FakeSystem {
    fn kind(&self, path: &Path) -> FileKind {
        self.files.get(path).copied().unwrap_or(FileKind::Missing)
    }
}

impl ConfiguratorBackend for FakeSystem {
    fn now_ms(&self) -> u64 {
        self.now
    }
    fn sleep_ms(&mut self, ms: u64) {
        self.calls.push(format!("sleep:{ms}"));
        self.now += ms;
    }
    fn status(&mut self, device: u8, budget_ms: u64) -> Result<ConfigStatus, ConfiguratorError> {
        self.calls.push(format!("status:{device}:{budget_ms}"));
        self.now += self.status_cost.min(budget_ms);
        if self.status_cost > budget_ms {
            return Err(ConfiguratorError::Timeout);
        }
        let status = self.statuses.pop_front().unwrap_or(self.last_status);
        self.last_status = status;
        Ok(status)
    }
    fn elevate(
        &mut self,
        executable: &Path,
        args: &[String],
        budget_ms: u64,
    ) -> Result<ProcessOutput, ConfiguratorError> {
        self.calls.push(format!(
            "elevate:{}:{}:{budget_ms}",
            executable.display(),
            args.join(" ")
        ));
        self.now += self.consent_cost;
        let accepted_at_ms = self.now;
        self.now += self.helper_cost;
        self.elevate_result.clone().map(|status| ProcessOutput {
            status,
            output: String::new(),
            accepted_at_ms,
        })
    }
    fn owned(&mut self, device: u8) -> Result<bool, ConfiguratorError> {
        Ok(self.marker[device as usize])
    }
    fn mark_owned(&mut self, device: u8, owned: bool) -> Result<(), ConfiguratorError> {
        self.calls.push(format!("marker:{device}:{owned}"));
        if owned && self.marker_write_fails {
            return Err(ConfiguratorError::MarkerWriteFailed);
        }
        self.marker[device as usize] = owned;
        Ok(())
    }
    fn pending(&mut self, device: u8) -> Result<bool, ConfiguratorError> {
        Ok(self.pending[device as usize])
    }
    fn mark_pending(&mut self, device: u8, pending: bool) -> Result<(), ConfiguratorError> {
        self.calls.push(format!("pending:{device}:{pending}"));
        self.pending[device as usize] = pending;
        Ok(())
    }
    fn confirmed(&mut self, device: u8) -> Result<bool, ConfiguratorError> {
        Ok(self.confirmed[device as usize])
    }
    fn mark_confirmed(&mut self, device: u8, confirmed: bool) -> Result<(), ConfiguratorError> {
        self.calls.push(format!("confirmed:{device}:{confirmed}"));
        self.confirmed[device as usize] = confirmed;
        Ok(())
    }
    fn reconcile_processes(&mut self) -> Result<(), ConfiguratorError> {
        if self.cleanup_incomplete {
            Err(ConfiguratorError::CleanupIncomplete)
        } else {
            Ok(())
        }
    }
}

#[test]
fn trust_requires_absolute_anchored_regular_trio_without_linked_component() {
    let (mut system, paths) = FakeSystem::installed();
    assert_eq!(
        trusted_resource(&system, &paths, "vJoyConfig.exe").unwrap(),
        paths.resources.join("vJoyConfig.exe")
    );
    system
        .files
        .insert(paths.anchor.clone(), FileKind::LinkOrReparse);
    assert_eq!(
        trusted_resource(&system, &paths, "vJoyConfig.exe"),
        Err(ConfiguratorError::UntrustedResource)
    );
    system
        .files
        .insert(paths.anchor.clone(), FileKind::Directory);
    system
        .files
        .insert(paths.resources.clone(), FileKind::LinkOrReparse);
    assert_eq!(
        trusted_resource(&system, &paths, "vJoyConfig.exe"),
        Err(ConfiguratorError::UntrustedResource)
    );
    system
        .files
        .insert(paths.resources.clone(), FileKind::Directory);
    system.files.insert(
        paths.resources.join("vJoyInstall.dll"),
        FileKind::LinkOrReparse,
    );
    system.statuses.push_back(ConfigStatus::Missing);
    assert_eq!(
        Configurator::new(paths.clone()).create(&mut system, 1),
        Err(ConfiguratorError::UntrustedResource)
    );
    assert!(!system.calls.iter().any(|call| call.starts_with("elevate:")));
    let (mut missing_interface, paths_with_interface) = FakeSystem::installed();
    missing_interface
        .files
        .remove(&paths_with_interface.resources.join("vJoyInterface.dll"));
    missing_interface.statuses.push_back(ConfigStatus::Missing);
    assert_eq!(
        Configurator::new(paths_with_interface).create(&mut missing_interface, 1),
        Err(ConfiguratorError::UntrustedResource)
    );
    assert!(!missing_interface
        .calls
        .iter()
        .any(|call| call.starts_with("elevate:")));
    let relative = ResourcePaths {
        anchor: PathBuf::from("installed"),
        resources: PathBuf::from("installed/resources"),
    };
    assert_eq!(
        trusted_resource(&system, &relative, "vJoyConfig.exe"),
        Err(ConfiguratorError::UntrustedResource)
    );
    let outside = ResourcePaths {
        anchor: paths.anchor,
        resources: PathBuf::from("/other/resources"),
    };
    assert_eq!(
        trusted_resource(&system, &outside, "vJoyConfig.exe"),
        Err(ConfiguratorError::UntrustedResource)
    );
}

#[test]
fn linked_strict_ancestor_above_anchor_is_untrusted() {
    let (mut system, paths) = FakeSystem::installed();
    system
        .files
        .insert(PathBuf::from("/installed"), FileKind::LinkOrReparse);
    assert_eq!(
        trusted_resource(&system, &paths, "vJoyConfig.exe"),
        Err(ConfiguratorError::UntrustedResource)
    );
    system.statuses.push_back(ConfigStatus::Missing);
    assert_eq!(
        Configurator::new(paths).create(&mut system, 1),
        Err(ConfiguratorError::UntrustedResource)
    );
    assert!(!system.calls.iter().any(|call| call.starts_with("elevate:")));
}

#[test]
fn marker_names_preserve_legacy_device_one_and_are_per_selected_id() {
    assert_eq!(marker_name(1).unwrap(), "VJoyDevice1CreatedByTrenino");
    assert_eq!(marker_name(16).unwrap(), "VJoyDevice16CreatedByTrenino");
    assert_eq!(marker_name(0), Err(ConfiguratorError::InvalidDevice));
    assert_eq!(marker_name(17), Err(ConfiguratorError::InvalidDevice));
}

#[test]
fn create_uses_fixed_selected_id_descriptor_and_marks_only_after_confirmation() {
    let (mut system, paths) = FakeSystem::installed();
    system.statuses = [
        ConfigStatus::Missing,
        ConfigStatus::Missing,
        ConfigStatus::Compatible,
    ]
    .into();
    Configurator::new(paths).create(&mut system, 7).unwrap();
    assert!(system.marker[7]);
    assert!(system.calls.iter().any(|call| call == "elevate:/installed/Trenino/resources/vJoyConfig.exe:7 -a x y z rx ry rz sl0 sl1 -b 32 -p 0:10000"));
    assert_eq!(
        system
            .calls
            .iter()
            .filter(|call| *call == "sleep:100")
            .count(),
        1
    );
    assert_eq!(system.calls.last().unwrap(), "pending:7:false");
    assert!(!system.marker[1]);
}

#[test]
fn create_maps_uac_cancel_and_refuses_busy_or_incompatible_without_elevation() {
    let (mut system, paths) = FakeSystem::installed();
    system.statuses.push_back(ConfigStatus::Missing);
    system.elevate_result = Err(ConfiguratorError::UacCancelled);
    assert_eq!(
        Configurator::new(paths.clone()).create(&mut system, 1),
        Err(ConfiguratorError::UacCancelled)
    );
    assert!(!system.marker[1]);
    for status in [ConfigStatus::Busy, ConfigStatus::Incompatible] {
        let (mut system, paths) = FakeSystem::installed();
        system.statuses.push_back(status);
        assert!(Configurator::new(paths).create(&mut system, 1).is_err());
        assert!(!system.calls.iter().any(|call| call.starts_with("elevate:")));
    }
}

#[test]
fn compatible_unmarked_device_is_foreign_and_never_adopted() {
    let (mut system, paths) = FakeSystem::installed();
    system.statuses.push_back(ConfigStatus::Compatible);
    assert_eq!(
        Configurator::new(paths).create(&mut system, 7),
        Err(ConfiguratorError::ForeignDevice)
    );
    assert!(!system.marker[7]);
    assert!(!system.calls.iter().any(|call| call.starts_with("elevate:")));
}

#[test]
fn delayed_uac_acceptance_receives_full_post_consent_deadline() {
    let (mut system, paths) = FakeSystem::installed();
    system.consent_cost = 15_000;
    system.helper_cost = 5_000;
    system.statuses = [ConfigStatus::Missing, ConfigStatus::Compatible].into();
    Configurator::new(paths).create(&mut system, 7).unwrap();
    assert_eq!(system.now, 20_000);
    assert!(system.marker[7]);
    assert!(!system.pending[7]);
}

#[test]
fn marker_write_failure_retains_pending_provenance_for_safe_retry() {
    let (mut system, paths) = FakeSystem::installed();
    system.statuses = [ConfigStatus::Missing, ConfigStatus::Compatible].into();
    system.marker_write_fails = true;
    let setup = Configurator::new(paths);
    assert_eq!(
        setup.create(&mut system, 7),
        Err(ConfiguratorError::MarkerWriteFailed)
    );
    assert!(!system.marker[7]);
    assert!(system.pending[7]);
    assert!(system.confirmed[7]);
    system.marker_write_fails = false;
    system.statuses.push_back(ConfigStatus::Compatible);
    setup.create(&mut system, 7).unwrap();
    assert!(system.marker[7]);
    assert!(!system.pending[7]);
    assert_eq!(
        system
            .calls
            .iter()
            .filter(|call| call.starts_with("elevate:"))
            .count(),
        1
    );
}

#[test]
fn stale_prelaunch_intent_never_authorizes_foreign_compatible_device() {
    let (mut system, paths) = FakeSystem::installed();
    system.pending[7] = true;
    system.statuses.push_back(ConfigStatus::Compatible);
    let setup = Configurator::new(paths);
    assert_eq!(
        setup.delete(&mut system, 7),
        Err(ConfiguratorError::ForeignDevice)
    );
    assert!(!system.marker[7]);
    assert!(!system.calls.iter().any(|call| call.starts_with("elevate:")));
}

#[test]
fn definite_launch_failure_cannot_adopt_later_foreign_device() {
    let (mut system, paths) = FakeSystem::installed();
    system.statuses = [ConfigStatus::Missing, ConfigStatus::Compatible].into();
    system.elevate_result = Err(ConfiguratorError::Native("launch failed".into()));
    assert_eq!(
        Configurator::new(paths).create(&mut system, 7),
        Err(ConfiguratorError::ForeignDevice)
    );
    assert!(!system.marker[7]);
    assert!(!system.confirmed[7]);
}

#[test]
fn timed_out_helper_cannot_claim_compatible_device_without_provenance() {
    let (mut system, paths) = FakeSystem::installed();
    system.statuses = [ConfigStatus::Missing, ConfigStatus::Compatible].into();
    system.elevate_result = Err(ConfiguratorError::Timeout);
    assert_eq!(
        Configurator::new(paths).create(&mut system, 7),
        Err(ConfiguratorError::ForeignDevice)
    );
    assert!(!system.marker[7]);
    assert!(!system.confirmed[7]);
}

#[test]
fn incomplete_helper_cleanup_blocks_a_second_mutation_and_keeps_pending_marker() {
    let (mut system, paths) = FakeSystem::installed();
    system.statuses.push_back(ConfigStatus::Missing);
    system.elevate_result = Err(ConfiguratorError::CleanupIncomplete);
    let setup = Configurator::new(paths);
    assert_eq!(
        setup.create(&mut system, 7),
        Err(ConfiguratorError::CleanupIncomplete)
    );
    assert!(system.pending[7]);
    system.cleanup_incomplete = true;
    let earlier_status_calls = system
        .calls
        .iter()
        .filter(|call| call.starts_with("status:"))
        .count();
    assert_eq!(
        setup.create(&mut system, 7),
        Err(ConfiguratorError::CleanupIncomplete)
    );
    assert_eq!(
        system
            .calls
            .iter()
            .filter(|call| call.starts_with("status:"))
            .count(),
        earlier_status_calls
    );
}

#[test]
fn stale_pending_marker_for_missing_device_is_cleared_without_elevation() {
    let (mut system, paths) = FakeSystem::installed();
    system.pending[7] = true;
    system.statuses.push_back(ConfigStatus::Missing);
    Configurator::new(paths).delete(&mut system, 7).unwrap();
    assert!(!system.pending[7]);
    assert!(!system.calls.iter().any(|call| call.starts_with("elevate:")));
}

#[test]
fn deadline_counts_slow_status_and_polling_without_marking_unconfirmed_device() {
    let (mut system, paths) = FakeSystem::installed();
    system.statuses.push_back(ConfigStatus::Missing);
    system.last_status = ConfigStatus::Missing;
    let result = Configurator::new(paths.clone()).create(&mut system, 1);
    assert_eq!(result, Err(ConfiguratorError::Timeout));
    assert_eq!(system.now, 10_000);
    assert!(!system.marker[1]);

    let (mut slow, paths) = FakeSystem::installed();
    slow.statuses.push_back(ConfigStatus::Missing);
    slow.status_cost = 10_001;
    assert_eq!(
        Configurator::new(paths).create(&mut slow, 1),
        Err(ConfiguratorError::Timeout)
    );
    assert_eq!(slow.now, 10_000);
    assert!(!slow.calls.iter().any(|call| call.starts_with("elevate:")));
}

#[test]
fn delete_requires_owned_nonbusy_selected_device_and_clears_marker_after_removal() {
    let (mut foreign, paths) = FakeSystem::installed();
    foreign.statuses.push_back(ConfigStatus::Compatible);
    assert_eq!(
        Configurator::new(paths.clone()).delete(&mut foreign, 3),
        Err(ConfiguratorError::ForeignDevice)
    );
    assert!(!foreign
        .calls
        .iter()
        .any(|call| call.starts_with("elevate:")));

    let (mut busy, paths) = FakeSystem::installed();
    busy.marker[3] = true;
    busy.statuses.push_back(ConfigStatus::Busy);
    assert_eq!(
        Configurator::new(paths).delete(&mut busy, 3),
        Err(ConfiguratorError::Busy)
    );
    assert!(busy.marker[3]);
    assert!(!busy.calls.iter().any(|call| call.starts_with("elevate:")));

    let (mut owned, paths) = FakeSystem::installed();
    owned.marker[3] = true;
    owned.statuses = [ConfigStatus::Compatible, ConfigStatus::Missing].into();
    Configurator::new(paths).delete(&mut owned, 3).unwrap();
    assert!(owned
        .calls
        .iter()
        .any(|call| call == "elevate:/installed/Trenino/resources/vJoyConfig.exe:-d 3:10000"));
    assert!(!owned.marker[3]);
    assert_eq!(owned.calls.last().unwrap(), "pending:3:false");
    assert!(!owned.marker[1]);
}

#[derive(Default)]
struct FakeProcessHost {
    now: u64,
    spawn_cost: u64,
    exit_at: Option<u64>,
    termination_fails: bool,
    reap_fails: bool,
    events: Vec<&'static str>,
}
struct FakeChild;
impl BoundedProcess for FakeProcessHost {
    type Child = FakeChild;
    fn now_ms(&self) -> u64 {
        self.now
    }
    fn sleep_ms(&mut self, ms: u64) {
        self.now += ms;
        self.events.push("sleep");
    }
    fn spawn(&mut self, _: &Path, _: &[String]) -> Result<Self::Child, ConfiguratorError> {
        self.events.push("spawn");
        self.now += self.spawn_cost;
        Ok(FakeChild)
    }
    fn poll(&mut self, _: &mut Self::Child) -> Result<Option<i32>, ConfiguratorError> {
        self.events.push("poll");
        Ok(self.exit_at.filter(|at| self.now >= *at).map(|_| 0))
    }
    fn terminate_tree(&mut self, _: &mut Self::Child) -> Result<(), ConfiguratorError> {
        self.events.push("kill_tree");
        if self.termination_fails {
            Err(ConfiguratorError::Native("kill failed".into()))
        } else {
            Ok(())
        }
    }
    fn reap(&mut self, _: &mut Self::Child) -> Result<ProcessOutput, ConfiguratorError> {
        self.events.push("reap");
        if self.reap_fails {
            return Err(ConfiguratorError::Native("reap failed".into()));
        }
        Ok(ProcessOutput {
            status: 0,
            output: String::new(),
            accepted_at_ms: 0,
        })
    }
    fn retain(&mut self, _: Self::Child) {
        self.events.push("retain");
    }
}

#[test]
fn process_deadline_terminates_tree_and_reaps_before_returning_timeout() {
    let mut host = FakeProcessHost::default();
    assert_eq!(
        run_bounded(&mut host, Path::new("/fixed/helper"), &[], 40),
        Err(ConfiguratorError::Timeout)
    );
    assert_eq!(host.now, 40);
    assert_eq!(&host.events[host.events.len() - 2..], ["kill_tree", "reap"]);
    host.exit_at = Some(50);
    assert_eq!(
        run_bounded(&mut host, Path::new("/fixed/status-worker"), &[], 40)
            .unwrap()
            .status,
        0
    );
    let mut completes = FakeProcessHost {
        exit_at: Some(20),
        ..Default::default()
    };
    assert_eq!(
        run_bounded(&mut completes, Path::new("/fixed/helper"), &[], 40)
            .unwrap()
            .status,
        0
    );
    assert!(!completes.events.contains(&"kill_tree"));
    assert_eq!(completes.events.last(), Some(&"reap"));

    let mut late_launch = FakeProcessHost {
        spawn_cost: 41,
        exit_at: Some(0),
        ..Default::default()
    };
    assert_eq!(
        run_bounded(&mut late_launch, Path::new("/fixed/helper"), &[], 40)
            .unwrap()
            .accepted_at_ms,
        41
    );
    assert_eq!(&late_launch.events, &["spawn", "poll", "reap"]);

    let mut cleanup_failure = FakeProcessHost {
        termination_fails: true,
        reap_fails: true,
        ..Default::default()
    };
    assert_eq!(
        run_bounded(&mut cleanup_failure, Path::new("/fixed/helper"), &[], 40),
        Err(ConfiguratorError::CleanupIncomplete)
    );
    assert_eq!(
        &cleanup_failure.events[cleanup_failure.events.len() - 3..],
        &["kill_tree", "reap", "retain"]
    );
}
