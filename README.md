# Hospital AI Receptionist (n8n + Claude)

A front-desk chat agent for a hospital OPD, built in n8n. Patients can book, reschedule or cancel appointments, ask about the hospital, and get handed to a human when the bot shouldn't handle it. Bookings are real rows in Postgres, not text the model makes up.

## How it works

```
POST /webhook/hospital-receptionist  { sessionId, message, channel, phone }
  -> normalize input, attach hospital config
  -> red-flag keyword check (chest pain, can't breathe, stroke signs, overdose...)
       match    -> log an emergency escalation, return a fixed "call 108 / 112, come to Emergency" reply
       no match -> AI agent (Claude) with Postgres chat memory and 6 tools
  -> { reply, sessionId, escalated }
```

Emergencies never reach the model. The keyword check runs first and the reply is hard-coded.

**Agent tools** (each is a parameterized Postgres query):

| Tool | What it does |
|---|---|
| `get_hospital_info` | departments, OPD hours, address, insurance, visiting hours, etc. |
| `find_available_slots` | soonest open slots by department / doctor / date |
| `book_appointment` | books a slot atomically (fails cleanly if someone else took it) and returns a reference code |
| `lookup_appointments` | upcoming appointments, only after phone + date of birth match |
| `cancel_appointment` | cancels by reference code + phone, frees the slot |
| `escalate_to_staff` | creates a callback ticket for billing, complaints, records, or "let me talk to a person" |

**Guardrails in the system prompt:** no diagnosis or medicine advice, never invent a slot, fee or doctor, verify identity before showing any existing appointment, read details back before booking, reply in whatever language the patient writes in, plain text only so replies work over WhatsApp or voice.

## Files

- `ai-receptionist-workflow.json` – the n8n workflow
- `schema.sql` – tables (doctors, slots, patients, appointments, escalations, hospital_info) plus sample data
- `chat.html` – a standalone patient chat page that talks to the webhook

## Setup

1. Create a `hospital` database and run `schema.sql`.
2. Import the workflow. Add a Postgres credential for that DB (host `postgres` if n8n runs in the same Docker network) and an Anthropic credential, then swap them in for the `REPLACE_..._CREDENTIAL_ID` placeholders.
3. In **Input + Hospital Config**, set the hospital name, address, emergency and front-desk numbers.
4. Replace the sample doctors, slots and hospital info with real ones.
5. Activate the workflow and open `chat.html` (change `WEBHOOK_URL` if n8n isn't on localhost:5678).

## Stack

n8n (Webhook, AI Agent, Postgres tools, Postgres chat memory), Anthropic Claude, PostgreSQL 16, plain HTML/JS for the chat page.
