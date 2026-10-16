-- AI Receptionist: database schema + sample seed data
-- Run once against a dedicated database (e.g. `hospital`), NOT the n8n system database.
-- Sample doctors / info below are placeholders: replace with the hospital's real data before going live.

CREATE TABLE IF NOT EXISTS doctors (
  id               SERIAL PRIMARY KEY,
  full_name        TEXT NOT NULL,
  department       TEXT NOT NULL,
  qualification    TEXT,
  languages        TEXT,
  consultation_fee INTEGER NOT NULL,
  is_active        BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS slots (
  id         SERIAL PRIMARY KEY,
  doctor_id  INTEGER NOT NULL REFERENCES doctors(id),
  start_time TIMESTAMPTZ NOT NULL,
  is_booked  BOOLEAN NOT NULL DEFAULT FALSE,
  UNIQUE (doctor_id, start_time)
);
CREATE INDEX IF NOT EXISTS slots_open_idx ON slots (start_time) WHERE is_booked = FALSE;

-- Phone is stored as the last 10 digits (Indian mobile). One phone can belong to several family members.
CREATE TABLE IF NOT EXISTS patients (
  id            SERIAL PRIMARY KEY,
  full_name     TEXT NOT NULL,
  phone         TEXT NOT NULL,
  date_of_birth DATE NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (phone, full_name)
);

CREATE TABLE IF NOT EXISTS appointments (
  id             SERIAL PRIMARY KEY,
  reference_code TEXT NOT NULL UNIQUE,
  slot_id        INTEGER NOT NULL REFERENCES slots(id),
  doctor_id      INTEGER NOT NULL REFERENCES doctors(id),
  patient_id     INTEGER NOT NULL REFERENCES patients(id),
  reason         TEXT,
  channel        TEXT,
  session_id     TEXT,
  status         TEXT NOT NULL DEFAULT 'confirmed' CHECK (status IN ('confirmed', 'cancelled', 'completed', 'no_show')),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Front-desk work queue: emergencies, callbacks, complaints, billing, anything the AI hands off.
CREATE TABLE IF NOT EXISTS escalations (
  id           SERIAL PRIMARY KEY,
  session_id   TEXT,
  channel      TEXT,
  type         TEXT NOT NULL CHECK (type IN ('emergency', 'callback', 'human_request', 'complaint', 'billing_insurance', 'reports_records', 'other')),
  urgency      TEXT NOT NULL DEFAULT 'normal' CHECK (urgency IN ('high', 'normal', 'low')),
  patient_name TEXT,
  phone        TEXT,
  summary      TEXT NOT NULL,
  status       TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'in_progress', 'resolved')),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS hospital_info (
  topic   TEXT PRIMARY KEY,
  content TEXT NOT NULL
);

-- ---------- Sample seed data (replace) ----------

INSERT INTO doctors (full_name, department, qualification, languages, consultation_fee) VALUES
  ('Dr. Sample Physician',   'General Medicine', 'MBBS, MD',          'English, Hindi, Telugu', 500),
  ('Dr. Sample Cardiologist', 'Cardiology',      'MBBS, MD, DM',      'English, Hindi',         900),
  ('Dr. Sample Orthopaedic',  'Orthopaedics',    'MBBS, MS (Ortho)',  'English, Telugu',        800),
  ('Dr. Sample Paediatrician','Paediatrics',     'MBBS, MD (Paeds)',  'English, Hindi, Telugu', 600),
  ('Dr. Sample Gynaecologist','Obstetrics & Gynaecology', 'MBBS, MS (OBG)', 'English, Hindi',   700),
  ('Dr. Sample Dermatologist','Dermatology',     'MBBS, MD (DVL)',    'English, Telugu',        600),
  ('Dr. Sample ENT',          'ENT',             'MBBS, MS (ENT)',    'English, Hindi',         600)
ON CONFLICT DO NOTHING;

-- 20-minute slots, Mon-Sat, 10:00-13:00 and 17:00-19:00 IST, for the next 14 days
INSERT INTO slots (doctor_id, start_time)
SELECT d.id, ts AT TIME ZONE 'Asia/Kolkata'
FROM doctors d
CROSS JOIN generate_series(
  date_trunc('day', NOW() AT TIME ZONE 'Asia/Kolkata') + INTERVAL '1 day',
  date_trunc('day', NOW() AT TIME ZONE 'Asia/Kolkata') + INTERVAL '15 days',
  INTERVAL '20 minutes'
) AS ts
WHERE EXTRACT(ISODOW FROM ts) < 7
  AND (ts::time >= '10:00' AND ts::time < '13:00' OR ts::time >= '17:00' AND ts::time < '19:00')
ON CONFLICT DO NOTHING;

INSERT INTO hospital_info (topic, content) VALUES
  ('opd_hours',        'OPD runs Monday to Saturday, 10:00 AM-1:00 PM and 5:00-7:00 PM. Closed Sundays and public holidays. Emergency is open 24/7.'),
  ('address',          'REPLACE: full address, landmark, Google Maps link.'),
  ('parking',          'REPLACE: parking details.'),
  ('what_to_bring',    'Photo ID, previous prescriptions and reports, list of current medicines, insurance card if applicable.'),
  ('payment',          'REPLACE: accepted payment modes (cash, UPI, cards).'),
  ('insurance',        'REPLACE: empanelled insurers/TPAs and cashless process. Detailed insurance queries go to the TPA desk.'),
  ('lab_and_imaging',  'REPLACE: lab timings, fasting instructions, report turnaround.'),
  ('visiting_hours',   'REPLACE: inpatient visiting hours and rules.'),
  ('pharmacy',         'REPLACE: in-house pharmacy hours.')
ON CONFLICT (topic) DO NOTHING;
