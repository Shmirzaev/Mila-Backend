ALTER TABLE employees
ADD COLUMN IF NOT EXISTS employee_no INTEGER;

CREATE UNIQUE INDEX IF NOT EXISTS idx_employees_employee_no
ON employees(employee_no)
WHERE employee_no IS NOT NULL;