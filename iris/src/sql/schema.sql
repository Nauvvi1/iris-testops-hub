-- Users
CREATE TABLE TestOps_User (
  id INTEGER IDENTITY PRIMARY KEY,
  email VARCHAR(255) UNIQUE NOT NULL,
  passHash VARCHAR(128) NOT NULL,
  passSalt VARCHAR(64) NOT NULL,
  role VARCHAR(32) NOT NULL DEFAULT 'admin',
  createdAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Sessions (bearer tokens)
CREATE TABLE TestOps_Session (
  token VARCHAR(64) PRIMARY KEY,
  userId INTEGER NOT NULL,
  expiresAt TIMESTAMP NOT NULL,
  createdAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_session_user ON TestOps_Session(userId);

-- Projects
CREATE TABLE TestOps_Project (
  id INTEGER IDENTITY PRIMARY KEY,
  name VARCHAR(200) NOT NULL,
  ownerId INTEGER NOT NULL,
  ingestToken VARCHAR(64) UNIQUE NOT NULL,
  createdAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_project_owner ON TestOps_Project(ownerId);

-- Runs
CREATE TABLE TestOps_Run (
  id INTEGER IDENTITY PRIMARY KEY,
  projectId INTEGER NOT NULL,
  commitSha VARCHAR(64),
  branch VARCHAR(128),
  ciProvider VARCHAR(64),
  startedAt TIMESTAMP,
  durationMs INTEGER,
  status VARCHAR(32) NOT NULL,
  createdAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_run_project ON TestOps_Run(projectId);
CREATE INDEX idx_run_created ON TestOps_Run(createdAt);

-- Errors (grouped by fingerprint)
CREATE TABLE TestOps_ErrorEvent (
  id INTEGER IDENTITY PRIMARY KEY,
  runId INTEGER NOT NULL,
  fingerprint VARCHAR(64) NOT NULL,
  message VARCHAR(2000),
  stacktrace VARCHAR(8000),
  createdAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_error_run ON TestOps_ErrorEvent(runId);
CREATE INDEX idx_error_fp ON TestOps_ErrorEvent(fingerprint);

-- Test cases
CREATE TABLE TestOps_TestCase (
  id INTEGER IDENTITY PRIMARY KEY,
  runId INTEGER NOT NULL,
  name VARCHAR(512) NOT NULL,
  status VARCHAR(32) NOT NULL,
  durationMs INTEGER,
  errorId INTEGER,
  annotation VARCHAR(64),
  createdAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_test_run ON TestOps_TestCase(runId);
CREATE INDEX idx_test_name ON TestOps_TestCase(name);

-- Attachments (logs, artifacts)
CREATE TABLE TestOps_Attachment (
  id INTEGER IDENTITY PRIMARY KEY,
  runId INTEGER,
  testCaseId INTEGER,
  fileName VARCHAR(512) NOT NULL,
  mime VARCHAR(128) NOT NULL DEFAULT 'application/octet-stream',
  sizeBytes INTEGER NOT NULL DEFAULT 0,
  storageKey VARCHAR(1024) NOT NULL,
  createdAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_att_run ON TestOps_Attachment(runId);
CREATE INDEX idx_att_test ON TestOps_Attachment(testCaseId);

-- Helpful views
CREATE VIEW TestOps_RunStats AS
SELECT
  r.id AS runId,
  r.projectId,
  r.commitSha,
  r.branch,
  r.ciProvider,
  r.startedAt,
  r.durationMs,
  r.status,
  r.createdAt,
  (SELECT COUNT(*) FROM TestOps_TestCase t WHERE t.runId=r.id) AS total,
  (SELECT COUNT(*) FROM TestOps_TestCase t WHERE t.runId=r.id AND t.status='passed') AS passed,
  (SELECT COUNT(*) FROM TestOps_TestCase t WHERE t.runId=r.id AND t.status='failed') AS failed
FROM TestOps_Run r;

