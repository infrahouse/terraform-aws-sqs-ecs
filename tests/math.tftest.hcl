// Pure-math tests for the scaling submodule. Runs offline via `terraform test`
// using `command = plan`. No provider required — the submodule is provider-free.
//
// Run from the repo root:
//   terraform init -test-directory=tests
//   terraform test -test-directory=tests

variables {
  // Defaults shared by all runs. Individual runs override as needed.
  instance_memory_available_mib = 768
  instance_cpu_available_units  = 1920
  task_quota_cpu                = 200
  task_quota_memory             = 128
  subnet_count                  = 2
  consumer_asg_min_size         = null
  consumer_asg_max_size         = null
  consumer_task_min_count       = null
  consumer_task_max_count       = null
}

run "small_instance_cpu_bound" {
  command = plan
  module { source = "./modules/scaling" }

  variables {
    // t3a.small after reservations: 768 MiB mem, 1920 CPU units.
    // Default quotas: 128 MiB / 200 CPU → floor(768/128)=6 mem, floor(1920/200)=9 cpu.
    // CPU-bound because min(6, 9) = 6.
    instance_memory_available_mib = 768
    instance_cpu_available_units  = 1920
  }

  assert {
    condition     = output.tasks_per_instance == 6
    error_message = "tpi: expected 6 (memory-bound: floor(768/128)), got ${output.tasks_per_instance}"
  }
  assert {
    condition     = output.asg_min_size == 2
    error_message = "asg_min_size: expected subnet_count=2, got ${output.asg_min_size}"
  }
  assert {
    condition     = output.asg_max_size == 3
    error_message = "asg_max_size: expected subnet_count+1=3, got ${output.asg_max_size}"
  }
  assert {
    condition     = output.task_min_count == 12
    error_message = "task_min_count: expected asg_min_size*tpi=2*6=12, got ${output.task_min_count}"
  }
  assert {
    condition     = output.task_max_count == 18
    error_message = "task_max_count: expected asg_max_size*tpi=3*6=18, got ${output.task_max_count}"
  }
}

run "large_instance_cpu_bound" {
  command = plan
  module { source = "./modules/scaling" }

  variables {
    // m5.large-ish: 8192 MiB memory, 2 vCPU. After reservations: 6912 MiB, 1920 CPU.
    // Default quotas: floor(6912/128)=54 mem, floor(1920/200)=9 cpu → CPU-bound at 9.
    instance_memory_available_mib = 6912
    instance_cpu_available_units  = 1920
  }

  assert {
    condition     = output.tasks_per_instance == 9
    error_message = "tpi: expected 9 (CPU-bound), got ${output.tasks_per_instance}"
  }
  assert {
    condition     = output.task_max_count == 27
    error_message = "task_max_count: expected asg_max_size*tpi=3*9=27, got ${output.task_max_count}"
  }
}

run "memory_bound" {
  command = plan
  module { source = "./modules/scaling" }

  variables {
    // Tight memory, generous CPU: floor(256/128)=2 mem, floor(2000/200)=10 cpu → memory-bound at 2.
    instance_memory_available_mib = 256
    instance_cpu_available_units  = 2000
  }

  assert {
    condition     = output.tasks_per_instance == 2
    error_message = "tpi: expected 2 (memory-bound), got ${output.tasks_per_instance}"
  }
  assert {
    condition     = output.task_min_count == 4
    error_message = "task_min_count: expected asg_min_size*tpi=2*2=4, got ${output.task_min_count}"
  }
}

run "instance_fits_exactly_one_task" {
  command = plan
  module { source = "./modules/scaling" }

  variables {
    // Exactly enough for one task.
    instance_memory_available_mib = 128
    instance_cpu_available_units  = 200
    task_quota_memory             = 128
    task_quota_cpu                = 200
  }

  assert {
    condition     = output.tasks_per_instance == 1
    error_message = "tpi: expected 1 (exact fit), got ${output.tasks_per_instance}"
  }
  assert {
    condition     = output.task_max_count == 3
    error_message = "task_max_count: expected 3*1=3, got ${output.task_max_count}"
  }
}

run "instance_too_small_floor_clamped_to_one" {
  command = plan
  module { source = "./modules/scaling" }

  variables {
    // Instance can't fit even one task. The `max(1, …)` clamp keeps tpi at 1 so
    // downstream math stays sane. The root module's precondition is responsible
    // for rejecting this configuration — the scaling module itself doesn't.
    instance_memory_available_mib = 64
    instance_cpu_available_units  = 100
    task_quota_memory             = 128
    task_quota_cpu                = 200
  }

  assert {
    condition     = output.tasks_per_instance == 1
    error_message = "tpi: expected 1 (clamp), got ${output.tasks_per_instance}"
  }
}

run "override_asg_min_and_max" {
  command = plan
  module { source = "./modules/scaling" }

  variables {
    instance_memory_available_mib = 768
    instance_cpu_available_units  = 1920
    // tpi = 6 (same as small_instance case)
    consumer_asg_min_size = 3
    consumer_asg_max_size = 7
  }

  assert {
    condition     = output.asg_min_size == 3
    error_message = "asg_min_size: expected user-provided 3, got ${output.asg_min_size}"
  }
  assert {
    condition     = output.asg_max_size == 7
    error_message = "asg_max_size: expected user-provided 7, got ${output.asg_max_size}"
  }
  assert {
    condition     = output.task_min_count == 18
    error_message = "task_min_count: expected 3*6=18, got ${output.task_min_count}"
  }
  assert {
    condition     = output.task_max_count == 42
    error_message = "task_max_count: expected 7*6=42, got ${output.task_max_count}"
  }
}

run "override_task_max_only" {
  command = plan
  module { source = "./modules/scaling" }

  variables {
    instance_memory_available_mib = 768
    instance_cpu_available_units  = 1920
    // tpi = 6
    consumer_task_max_count = 30
  }

  assert {
    condition     = output.tasks_per_instance == 6
    error_message = "tpi: expected 6, got ${output.tasks_per_instance}"
  }
  assert {
    condition     = output.asg_max_size == 5
    error_message = "asg_max_size: expected ceil(30/6)=5, got ${output.asg_max_size}"
  }
  assert {
    condition     = output.task_max_count == 30
    error_message = "task_max_count: expected user-provided 30, got ${output.task_max_count}"
  }
}

run "override_task_min_only" {
  command = plan
  module { source = "./modules/scaling" }

  variables {
    instance_memory_available_mib = 768
    instance_cpu_available_units  = 1920
    consumer_task_min_count       = 10
  }

  assert {
    condition     = output.task_min_count == 10
    error_message = "task_min_count: expected user-provided 10, got ${output.task_min_count}"
  }
}
