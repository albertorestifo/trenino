# Atomic lever mapping save

Root implementation changes storage/domain/trains.rs, reusable binding/config tx bodies, domain advance_topic helper, preview pure-from-input helper, AppServices guarded commit and desktop runtime_mapping.rs.

`ui_commit_lever_mapping(mapping)` snake_case accepts:
```
{ element_id:string, lever_config_id:string|null, input_id:string,
  replace_binding:boolean,
  endpoints:{min_endpoint,max_endpoint,value_endpoint,notch_count_endpoint?:string|null,notch_index_endpoint?:string|null,lever_type?:'continuous'|'discrete'|'hybrid'|null},
  notches:NotchDraft[], captured_ranges:CapturedRange[], auto_distribute:boolean }
```
Returns `{ train_detail:UiSnapshot<TrainDetailView>, validation:UiSnapshot<NotchRangesValidationView> }`.

Within ONE SQLite worker transaction: validates actual lever element + matching current config id, reloads persisted analog input/calibration, recomputes normalized ranges/inversion using shared Rust preview logic, ignores caller input_min/max, validates endpoints, creates/updates config, binds input under existing exclusivity rules, replaces notches, increments trains and bindings revisions. Missing lever_type preserves existing. Auto-distribute preserves existing inversion. Explicit save can commit gaps and returns validation, allowing retained acknowledge-gaps workflow.

UI must replace create/bind/save/update/validate chain with this command; on conflict keep draft and offer replacement; on success read result.train_detail and result.validation. Endpoints edited in existing wizard now actually persist. No writes occur on Continue/Preview.

Validation: injected final-notch INSERT trigger failure proves config creation, binding, notches, topic revisions all rollback; same failure during edit preserves original complete config. Successful case recomputes untrusted999.0 input ranges to0..1, stores binding, increments each topic once. New test1 + existing domain_trains and domain_bindings suites pass. preview3 pass. Desktop rust-ui check passes before latest exact-target manual action API change. No physical effects involved.
