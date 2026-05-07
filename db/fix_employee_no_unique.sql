-- Проверяем и исправляем уникальность employee_no

ALTER TABLE employees
ADD COLUMN IF NOT EXISTS employee_no INTEGER;

DROP INDEX IF EXISTS idx_employees_employee_no;

ALTER TABLE employees
DROP CONSTRAINT IF EXISTS employees_employee_no_unique;

ALTER TABLE employees
ADD CONSTRAINT employees_employee_no_unique UNIQUE (employee_no);

CREATE INDEX IF NOT EXISTS idx_employees_status
ON employees(status);

CREATE INDEX IF NOT EXISTS idx_employees_department
ON employees(department_id);