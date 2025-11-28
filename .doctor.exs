%Doctor.Config{
  ignore_modules: [],
  ignore_paths: [
    "lib/premiere_ecoute_core/aggregate.ex",
    "lib/premiere_ecoute_core/command_bus/handler.ex",
    "lib/premiere_ecoute_core/event_bus/handler.ex"
  ],
  min_module_doc_coverage: 100,
  min_module_spec_coverage: 100,
  min_overall_doc_coverage: 100,
  min_overall_moduledoc_coverage: 100,
  min_overall_spec_coverage: 100,
  exception_moduledoc_required: true,
  raise: false,
  reporter: Doctor.Reporters.Full,
  struct_type_spec_required: true,
  umbrella: false
}
