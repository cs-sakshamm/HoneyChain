# HoneyChain Workflow Audit

Date: 2026-09-19

## Issue: Request dashboards exposed all workflow requests

Root Cause:
`GET /api/requests` returned collection, lab, and packaging records without scoping them to the authenticated user's role or ownership.

Affected File:
`backend/main.py`

Fix Applied:
Added role-aware filtering for harvester, collection/processing, lab, packaging, and admin views. Lab and packaging records are now surfaced only when the authenticated user is a relevant actor for that batch/stage.

Validation/Test:
`backend/.venv/Scripts/python.exe -m pytest backend/tests -q`

Status:
FIXED

## Issue: Duplicate active collection/lab requests could be created

Root Cause:
Request creation did not check for an existing active request for the same batch, sender, recipient, and workflow stage.

Affected File:
`backend/main.py`

Fix Applied:
Added duplicate detection for Harvester to Collection requests and Collection to Lab requests. Active duplicates now return `409 DUPLICATE_REQUEST`.

Validation/Test:
`backend/tests/test_supply_chain_guards.py::test_duplicate_collection_request_is_blocked`

Status:
FIXED

## Issue: Backend trusted frontend role/actor hints during workflow transitions

Root Cause:
Some send/accept paths read `actorRole` or display-name-like actor values from the frontend instead of deriving permissions from the authenticated JWT user.

Affected Files:
`backend/main.py`
`mobile_app/lib/features/collection/screens/nearest_centres_screen.dart`
`mobile_app/lib/features/collection/screens/collection_dashboard_screen.dart`

Fix Applied:
Backend transition permissions now derive from `current_user.role`. Mobile send-to-lab/send-to-packaging paths now pass the real authenticated user ID where actor ID fields are still sent for compatibility.

Validation/Test:
`backend/tests/test_supply_chain_guards.py::test_lab_request_accept_requires_lab_role`

Status:
FIXED

## Issue: Lab acceptance and packaging acceptance lacked complete state/role guards

Root Cause:
Lab requests could be accepted without enforcing lab role/assignment, and packaging batches could be accepted before required upstream validation.

Affected File:
`backend/main.py`

Fix Applied:
Lab acceptance now requires an authenticated lab account assigned to the request. Packaging acceptance now requires a packaging role, a passed lab report, and a packaging-ready batch state.

Validation/Test:
`backend/.venv/Scripts/python.exe -m pytest backend/tests/test_supply_chain_guards.py -q`

Status:
FIXED

## Issue: Packaging endpoint allowed incomplete or failed chains

Root Cause:
`POST /api/packaging` created final QR/package records without checking that harvest, collection, processing, and passed lab test stages existed.

Affected File:
`backend/main.py`

Fix Applied:
Packaging now validates the complete required chain and rejects missing stages or failed lab tests with meaningful errors.

Validation/Test:
`backend/tests/test_supply_chain_guards.py::test_packaging_blocked_after_failed_lab_test`

Status:
FIXED

## Issue: Blockchain provenance records were not consistently linked

Root Cause:
Routes independently created `BlockchainRecord` entries and usually omitted `previous_event_hash`.

Affected File:
`backend/main.py`

Fix Applied:
Added `_record_provenance()` helper that records through the blockchain service and stores the latest previous event hash for linked batch history.

Validation/Test:
Full backend e2e tests and blockchain test:
`backend/.venv/Scripts/python.exe -m pytest backend/tests -q`
`npm.cmd test` in `blockchain`

Status:
FIXED

## Issue: Public verifier overclaimed authenticity and used demo fallbacks

Root Cause:
The verifier displayed language like "genuine" and used hardcoded fallback batch data, facilities, dates, counts, and contract addresses when real data was missing.

Affected Files:
`backend/main.py`
`web/src/App.tsx`
`web/src/components/ProductSummary.tsx`
`web/src/components/ProvenanceTimeline.tsx`
`web/src/components/PackagingInfo.tsx`
`web/src/components/BlockchainProof.tsx`

Fix Applied:
Changed verification language to tamper-evident traceability, removed the homepage demo verification card/sample QR, removed fake fallback chain values, and made missing stages explicit.

Validation/Test:
`npm.cmd run build` in `web`

Status:
FIXED

## Issue: Web verifier dev toolchain had npm audit vulnerabilities

Root Cause:
The verifier package used an older Vite/esbuild toolchain flagged by `npm audit`.

Affected Files:
`web/package.json`
`web/package-lock.json`

Fix Applied:
Upgraded Vite and the compatible React plugin. Rebuilt the verifier after the upgrade and refreshed the backend-served verifier bundle.

Validation/Test:
`npm.cmd audit --audit-level=high`
`npm.cmd run build`

Status:
FIXED

## Issue: Nearest-center card showed fallback location instead of real center location

Root Cause:
The mobile card read `center['address']`, but the backend returns `location`.

Affected File:
`mobile_app/lib/features/collection/screens/nearest_centres_screen.dart`

Fix Applied:
The card now displays `center['location']` and falls back only to "Location unavailable".

Validation/Test:
Static code inspection and backend nearest-center API shape review.

Status:
FIXED

## Issue: Existing e2e tests skipped the real request acceptance flow

Root Cause:
Tests processed and certified batches directly without exercising collection acceptance, lab request creation, lab acceptance, and send-to-packaging.

Affected Files:
`backend/tests/test_e2e_integration.py`
`backend/tests/test_scenario_49.py`

Fix Applied:
Updated e2e tests to follow the real chain:
Harvest -> Collection Request -> Collection Accept -> Processing -> Lab Request -> Lab Accept -> Lab Report -> Send Packaging -> Packaging -> Public Verify.

Validation/Test:
`backend/.venv/Scripts/python.exe -m pytest backend/tests/test_e2e_integration.py backend/tests/test_scenario_49.py -q`

Status:
FIXED

## Validation Summary

Passed:
- Backend full test suite: `12 passed`
- Backend startup smoke test: FastAPI started on `127.0.0.1:8019`
- Backend health: `/api/health` returned `status=healthy`
- React verifier build: `npm.cmd run build`
- Web verifier security audit: `npm.cmd audit --audit-level=high` reported `found 0 vulnerabilities`
- Blockchain contract test: `npm.cmd test`

Not Completed:
- Flutter test execution: `flutter --version` hung without output and was interrupted. No Flutter test result is claimed.

Environment Notes:
- Backend startup attempted Postgres first, then fell back to local SQLite because local Postgres authentication failed for user `postgres`.
- Blockchain RPC at `127.0.0.1:8545` was offline, so backend health reported `Offline (Ledger Ready)` and tests used tamper-evident hash records rather than confirmed live transactions.

## FRAMER MOTION ANIMATION AUDIT

Animation Inventory:
- HC-FM-001
- HC-FM-002
- HC-FM-003
- HC-FM-004
- HC-FM-005
- HC-FM-006
- HC-FM-007
- HC-FM-008
- HC-FM-009

### Animation ID: HC-FM-001
File: web/src/App.tsx
Component: App, Landing Page
Page/Section: Root Landing Page
Animation Type: Fade + Scale + Slide (Entrance & Exit)
Trigger: Page Load / State Change
Duration: 300ms
Purpose: Smooth page entrance and exit transitions
Reduced Motion: Supported
Testing Status: PASS

### Animation ID: HC-FM-002
File: web/src/pages/VerifyPage.tsx
Component: VerifyPage
Page/Section: Verification Page
Animation Type: Stagger Container + Fade/Scale (Loading, Error, Results)
Trigger: Data Loading State Changes
Duration: 200ms
Purpose: Smooth sequential loading of dashboard cards
Reduced Motion: Supported
Testing Status: PASS

### Animation ID: HC-FM-003
File: web/src/components/ProductSummary.tsx
Component: ProductSummary
Page/Section: Verify Page / Authenticity Hero
Animation Type: Hover Scale + PopLayout (Status Pill)
Trigger: Component Entrance / Hover / State Change
Duration: 150ms-200ms
Purpose: Premium interactive feel and status change emphasis
Reduced Motion: Supported
Testing Status: PASS

### Animation ID: HC-FM-004
File: web/src/components/ProvenanceTimeline.tsx
Component: ProvenanceTimeline
Page/Section: Verify Page / Traceability
Animation Type: Staggered Fade + Slide (Nodes), Spring Scale (Dots)
Trigger: Scroll into view (Viewport)
Duration: 300ms
Purpose: Progressive revelation of the traceability chain
Reduced Motion: Supported
Testing Status: PASS

### Animation ID: HC-FM-005
File: web/src/components/BlockchainProof.tsx
Component: BlockchainProof
Page/Section: Verify Page / Blockchain
Animation Type: Staggered Fade + Slide (Event Log)
Trigger: Scroll into view (Viewport)
Duration: 200ms
Purpose: Sequential appearance of ledger events
Reduced Motion: Supported
Testing Status: PASS

### Animation ID: HC-FM-006
File: web/src/components/LabReport.tsx
Component: LabReport
Page/Section: Verify Page / Lab Test
Animation Type: AnimatePresence Fade + Scale (Modal), Hover/Tap (Buttons)
Trigger: Button Click / Hover
Duration: 200ms
Purpose: Smooth modal presentation for chemical analysis certificate
Reduced Motion: Supported
Testing Status: PASS

### Animation ID: HC-FM-007
File: web/src/components/IoTTelemetry.tsx
Component: IoTTelemetry
Page/Section: Verify Page / Telemetry
Animation Type: AnimatePresence Height + Opacity (JSON Toggle), Hover
Trigger: Technical Data Toggle / Hover
Duration: 200ms
Purpose: Smooth accordion expansion for technical details
Reduced Motion: Supported
Testing Status: PASS

### Animation ID: HC-FM-008
File: web/src/components/AIAnalysis.tsx, web/src/components/PackagingInfo.tsx
Component: AIAnalysis, PackagingInfo
Page/Section: Verify Page / AI & Packaging
Animation Type: Card Hover Scale
Trigger: Mouse Hover
Duration: 150ms
Purpose: Consistent micro-interactions across UI cards
Reduced Motion: Supported
Testing Status: PASS

### Animation ID: HC-FM-009
File: web/src/components/QRDisplay.tsx
Component: QRDisplay
Page/Section: Verify Page / QR
Animation Type: Fade + Scale Entrance, Icon Swap (Copy)
Trigger: Scroll into view, Copy Button Click
Duration: 400ms (Entrance), 200ms (Icon Swap)
Purpose: Visual stability for QR scanning with clear copy feedback
Reduced Motion: Supported
Testing Status: PASS

