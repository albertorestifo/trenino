# Multiple Train Identifiers Design

## Context

Trenino currently stores one unique identifier on each train profile. Detection treats that identifier as a prefix of the simulator's detected `ObjectClass`, which supports suffix variants such as `RVM_LIRREX_M9-A` and `RVM_LIRREX_M9-B` under one profile.

That model does not support the same train configuration appearing under unrelated prefixes. For example, route-specific BR423 variants may have identifiers such as `RVM_FSN_DB_BR423` and another route-specific prefix even though they share the same hardware configuration.

## Goals

- Allow one train profile to belong to multiple equivalent identifier prefixes.
- Treat every identifier equally; there is no primary or canonical identifier.
- Ensure an exact identifier belongs to only one train profile.
- Preserve prefix matching for each identifier.
- Preserve ambiguity reporting when different train profiles match a detected identifier.
- Migrate every existing train profile without losing its identifier.
- Replace singular identifier fields in the HTTP and MCP APIs with identifier arrays.

## Non-goals

- Changing how the simulator derives an identifier from a formation.
- Changing detection events or active-train lifecycle behavior.
- Selecting a match automatically when identifiers from different profiles overlap.
- Changing hardware mappings, elements, bindings, scripts, or other train-profile configuration.
- Preserving the old singular API field as a compatibility alias.

## Data Model

Add a `train_identifiers` table with:

- `id`
- `train_id`, a required foreign key to `trains` with cascade deletion
- `identifier`, a required string
- timestamps consistent with the rest of the application

Create a unique index on `identifier` so an exact identifier can belong to only one train profile. Create an index on `train_id` for association loading.

Add a `Trenino.Train.TrainIdentifier` schema that belongs to `Trenino.Train.Train`. Replace the train schema's singular `identifier` field with a `has_many :identifiers` association. Association entries are replaceable during profile edits so removed form rows are deleted.

Identifier values are trimmed and must not be empty. Matching remains case-sensitive to preserve current behavior. A train profile must have at least one identifier. Duplicate values within one submitted profile are rejected before persistence, while the database constraint handles conflicts with another profile.

The migration performs these steps in order:

1. Create `train_identifiers` and its indexes.
2. Copy every existing `trains.identifier` into a row associated with that train.
3. Remove the unique index and `identifier` column from `trains`.

The reverse migration restores one identifier per train only if rollback support can do so without inventing a primary identifier. Because the new model deliberately has no primary value, the migration may be irreversible after a profile gains multiple identifiers; this must be explicit rather than silently discarding data.

## Context and Persistence Operations

`Trenino.Train.create_train/1` and `update_train/2` accept identifier values as a collection and persist the train plus its identifiers atomically. A validation or uniqueness failure rolls back the entire operation so a profile is never left with a partially applied identifier set.

Train queries used by the editor, list, HTTP API, and MCP tools preload identifiers explicitly. API-facing serialization converts associated records to a consistently ordered list of strings.

Existing callers that create test or application data with a singular `identifier` attribute are updated to the new collection shape. The application will not retain a hidden primary identifier or synthesize one from collection order.

## Detection

`get_train_by_identifier/1` compares the detected identifier with every stored identifier using the existing prefix rule:

```text
String.starts_with?(detected_identifier, stored_identifier)
```

Matching identifiers are mapped to their train profiles and deduplicated by train ID. This produces these results:

- No matching profile: `{:error, :not_found}`.
- Exactly one matching profile: `{:ok, train}`.
- More than one matching profile: `{:error, {:multiple_matches, trains}}`.

Deduplication is important when two overlapping identifiers belong to the same profile; that situation is still one unambiguous train match. Overlapping prefixes owned by different profiles continue to produce the existing ambiguity result.

Detection broadcasts and the active-train state retain the full identifier detected from the simulator. Only profile lookup changes.

## Train Editor

Replace the single train-identifier input with a repeatable list of identifier inputs. The editor provides controls to add and remove rows. Identifier order has no semantic meaning.

The form behavior is:

- A new blank profile starts with one empty identifier input.
- Creating a profile from a detected train seeds one input with the detected identifier.
- An existing profile displays all saved identifiers.
- The user can add or remove identifier rows.
- The form cannot be saved with zero non-empty identifiers.
- Empty values, duplicates in the same profile, and identifiers owned by another profile produce field-level validation errors.

All other profile editing behavior remains unchanged.

## HTTP and MCP Contracts

This is an intentional breaking change. Train representations in the HTTP API and MCP tools replace:

```json
{"identifier": "RVM_FSN_DB_BR423"}
```

with:

```json
{"identifiers": ["RVM_FSN_DB_BR423", "RVM_OTHER_DB_BR423"]}
```

The response contains only strings, sorted consistently for deterministic clients and tests. The singular `identifier` field is removed rather than retained as a deprecated alias because no identifier is primary.

## Error Handling

- Validation errors are returned through the existing train changeset and rendered beside the identifier collection in the editor.
- Exact cross-profile conflicts use the database unique constraint as the source of truth, preventing races between validation and insertion.
- Persistence is transactional so any failed identifier insert or deletion leaves the previous profile unchanged.
- Runtime overlap between different prefixes remains an explicit detection ambiguity and follows the existing warning and broadcast behavior.

## Testing

Automated coverage will include:

- Migrating an existing singular identifier into `train_identifiers` without data loss.
- Creating and updating a train with multiple identifiers.
- Rejecting an empty identifier collection.
- Rejecting duplicate identifiers within one profile.
- Rejecting exact identifier ownership by another profile.
- Matching a profile through each of its prefixes, including suffix variants.
- Deduplicating multiple matching prefixes owned by one profile.
- Returning ambiguity when matching prefixes belong to different profiles.
- Pre-filling the first identifier when creating a profile from detection.
- Adding and removing identifier fields in the LiveView editor.
- Returning `identifiers` arrays and no singular `identifier` field from HTTP and MCP APIs.
- Displaying identifier collections correctly in train-list and shared UI components.

Relevant documentation and the changelog will describe multiple identifiers and include a route-specific BR423 example.
