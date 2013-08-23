
optimsoc_inc_dir ${OPTIMSOC_RTL}/debug_system/verilog
optimsoc_add_file debug_system.v
optimsoc_add_file global_timestamp_provider.v
optimsoc_add_file dbgnoc_conf_if.v
optimsoc_add_file tcm.v
optimsoc_add_file ctm.v
optimsoc_add_file itm.v
optimsoc_add_file itm_dbgnoc_if.v
optimsoc_add_file debug_data_sr.v
optimsoc_add_file itm_trace_collector.v
optimsoc_add_file itm_trace_compression.v
optimsoc_add_file itm_trace_qualificator.v
optimsoc_add_file stm.v
optimsoc_add_file stm_data_sr.v
optimsoc_add_file stm_trace_collector.v
optimsoc_add_file stm_dbgnoc_if.v
optimsoc_add_file nrm.v
optimsoc_add_file nrm_statistics_collector.v
optimsoc_add_file nrm_link_statistics_collector.v
optimsoc_add_file nrm_dbgnoc_if.v
optimsoc_add_file ncm.v
optimsoc_add_file mam_wb_adapter.v
optimsoc_add_file mam.v

optimsoc_inc_dir ${LISNOC_RTL}/lisnoc16/
optimsoc_inc_dir ${LISNOC_RTL}/lisnoc16/converter
lisnoc_add_file rings/lisnoc_uni_ring.v
lisnoc_add_file router/lisnoc_router_uni_ring.v
lisnoc_add_file lisnoc16/lisnoc16_fifo.v
lisnoc_add_file infrastructure/lisnoc_vc_multiplexer.v
lisnoc_add_file lisnoc16/converter/lisnoc16_converter_16to32.v
lisnoc_add_file lisnoc16/converter/lisnoc16_converter_32to16.v
