CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS departments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    department_key TEXT NOT NULL UNIQUE,
    title TEXT NOT NULL,
    description TEXT,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS employees (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    full_name TEXT NOT NULL,
    short_name TEXT,

    department_id UUID REFERENCES departments(id) ON DELETE SET NULL,

    position TEXT,
    phone TEXT,
    telegram_username TEXT,
    telegram_chat_id TEXT,

    access_level TEXT NOT NULL DEFAULT 'employee'
        CHECK (access_level IN ('ceo', 'admin', 'manager', 'employee')),

    status TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'inactive', 'fired', 'vacation')),

    notes TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS telegram_targets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    target_key TEXT NOT NULL UNIQUE,
    title TEXT NOT NULL,

    chat_id TEXT NOT NULL,
    target_type TEXT NOT NULL DEFAULT 'group'
        CHECK (target_type IN ('group', 'channel', 'private')),

    department_id UUID REFERENCES departments(id) ON DELETE SET NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE employees
ADD COLUMN IF NOT EXISTS employee_no INTEGER;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'employees_employee_no_unique'
          AND conrelid = 'employees'::regclass
    ) THEN
        ALTER TABLE employees
        ADD CONSTRAINT employees_employee_no_unique UNIQUE (employee_no);
    END IF;
END
$$;

CREATE INDEX IF NOT EXISTS idx_employees_employee_no
ON employees(employee_no);

CREATE INDEX IF NOT EXISTS idx_employees_department
ON employees(department_id);

CREATE INDEX IF NOT EXISTS idx_employees_status
ON employees(status);

CREATE INDEX IF NOT EXISTS idx_telegram_targets_key
ON telegram_targets(target_key);

INSERT INTO departments (department_key, title, description)
VALUES
    ('management', 'Management', 'Company leadership and executive management'),
    ('sales', 'Sales', 'Sales team and client communication'),
    ('design', 'Design', 'Design team and creative direction'),
    ('innovations', 'Innovations', 'Innovation projects, automation, and development')
ON CONFLICT (department_key) DO NOTHING;
