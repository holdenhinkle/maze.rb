CREATE TYPE formula_status AS ENUM ('pending', 'approved', 'rejected');

CREATE TABLE maze_formulas (
  id serial PRIMARY KEY,
  background_job_id integer REFERENCES background_jobs(id) ON DELETE CASCADE,
  maze_type text NOT NULL,
  unique_square_set text NOT NULL,
  x integer NOT NULL CHECK (x > 0),
  y integer NOT NULL CHECK (y > 0),
  endpoints integer NOT NULL CHECK (endpoints >= 0),
  barriers integer NOT NULL DEFAULT 0,
  bridges integer NOT NULL DEFAULT 0,
  tunnels integer NOT NULL DEFAULT 0,
  portals integer NOT NULL DEFAULT 0,
  experiment boolean NOT NULL DEFAULT FALSE,
  status formula_status NOT NULL DEFAULT 'pending',
  created timestamp NOT NULL DEFAULT NOW(),
  updated timestamp NOT NULL DEFAULT NOW()
);

CREATE TABLE maze_formula_set_permutations (
  id serial PRIMARY KEY,
  background_job_id integer NOT NULL REFERENCES background_jobs(id) ON DELETE CASCADE,
  maze_formula_id integer NOT NULL REFERENCES maze_formulas(id) ON DELETE CASCADE,
  permutation text NOT NULL,
  created timestamp NOT NULL DEFAULT NOW(),
  updated timestamp NOT NULL DEFAULT NOW()
);

CREATE TABLE maze_candidates (
  id serial PRIMARY KEY,
  background_job_id integer NOT NULL REFERENCES background_jobs(id) ON DELETE CASCADE,
  maze_formula_set_permutation_id integer NOT NULL REFERENCES maze_formula_set_permutations(id) ON DELETE CASCADE,
  number_of_solutions integer NOT NULL,
  solutions text NOT NULL,
  created timestamp NOT NULL DEFAULT NOW(),
  updated timestamp NOT NULL DEFAULT NOW()
);

CREATE TYPE worker_status AS ENUM ('alive', 'dead');

CREATE TABLE background_workers (
  id serial PRIMARY KEY,
  status worker_status DEFAULT 'alive',
  created timestamp NOT NULL DEFAULT NOW(),
  updated timestamp NOT NULL DEFAULT NOW()
);

CREATE TYPE thread_status AS ENUM ('alive', 'dead');

CREATE TABLE background_threads (
  id serial PRIMARY KEY,
  background_worker_id integer NOT NULL REFERENCES background_workers(id),
  status thread_status NOT NULL DEFAULT 'alive',
  created timestamp NOT NULL DEFAULT NOW(),
  updated timestamp NOT NULL DEFAULT NOW()
);

CREATE TYPE job_type AS ENUM ('generate_maze_formulas', 'generate_maze_permutations', 'generate_maze_candidates');

CREATE TYPE job_status AS ENUM ('queued', 'running', 'completed', 'failed');

CREATE TABLE background_jobs (
  id serial PRIMARY KEY,
  queue_order integer,
  background_worker_id integer REFERENCES background_workers(id),
  background_thread_id integer REFERENCES background_threads(id),
  job_type job_type NOT NULL,
  params text NOT NULL,
  status job_status NOT NULL DEFAULT 'queued',
  created timestamp NOT NULL DEFAULT NOW(),
  updated timestamp NOT NULL DEFAULT NOW()
);

CREATE TABLE admin_notifications (
  id serial PRIMARY KEY,
  notification TEXT NOT NULL,
  delivered BOOLEAN NOT NULL DEFAULT FALSE,
  created timestamp NOT NULL DEFAULT NOW(),
  updated timestamp NOT NULL DEFAULT NOW()
);

CREATE TABLE settings (
  id serial PRIMARY KEY,
  name text NOT NULL,
  integer_value integer,
  text_value text,
  updated_by text NOT NULL,
  created timestamp NOT NULL DEFAULT NOW(),
  updated timestamp NOT NULL DEFAULT NOW()
);

INSERT INTO settings (name, integer_value, updated_by) VALUES ('number_of_threads', 1, 'default setting');