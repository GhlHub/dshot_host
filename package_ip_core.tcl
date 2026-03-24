set ip_root [file normalize "/raid/work/dshot/ip_core"]
set component_xml [file join $ip_root component.xml]

proc ensure_productguide_metadata {component_xml} {
    set fp [open $component_xml r]
    set component_text [read $fp]
    close $fp

    set productguide_view {
      <spirit:view>
        <spirit:name>xilinx_productguide</spirit:name>
        <spirit:displayName>Product Guide</spirit:displayName>
        <spirit:envIdentifier>:vivado.xilinx.com:docs.productguide</spirit:envIdentifier>
        <spirit:fileSetRef>
          <spirit:localName>xilinx_productguide_view_fileset</spirit:localName>
        </spirit:fileSetRef>
      </spirit:view>
}

    set productguide_fileset {
    <spirit:fileSet>
      <spirit:name>xilinx_productguide_view_fileset</spirit:name>
      <spirit:file>
        <spirit:name>https://github.com/GhlHub/dshot_host</spirit:name>
        <spirit:userFileType>text</spirit:userFileType>
      </spirit:file>
    </spirit:fileSet>
}

    if {![string match "*<spirit:name>xilinx_productguide</spirit:name>*" $component_text]} {
        regsub {(\s*</spirit:views>)} $component_text "${productguide_view}\\1" component_text
    }

    if {![string match "*<spirit:name>xilinx_productguide_view_fileset</spirit:name>*" $component_text]} {
        regsub {(\s*</spirit:fileSets>)} $component_text "${productguide_fileset}\\1" component_text
    }

    set component_text [string map [list \
        {<xilinx:advertisementURL>https://example.invalid</xilinx:advertisementURL>} \
        {<xilinx:advertisementURL>https://github.com/GhlHub/dshot_host</xilinx:advertisementURL>} \
        {<xilinx:vendorURL>https://example.invalid</xilinx:vendorURL>} \
        {<xilinx:vendorURL>https://github.com/GhlHub/dshot_host</xilinx:vendorURL>} \
    ] $component_text]

    if {![string match "*<xilinx:advertisementURL>*" $component_text]} {
        regsub {(<xilinx:definitionSource>package_project</xilinx:definitionSource>)} \
            $component_text "\\1\n      <xilinx:advertisementURL>https://github.com/GhlHub/dshot_host</xilinx:advertisementURL>" \
            component_text
    }

    if {![string match "*<xilinx:vendorURL>*" $component_text]} {
        regsub {(<xilinx:definitionSource>package_project</xilinx:definitionSource>\n\s*<xilinx:advertisementURL>https://github.com/GhlHub/dshot_host</xilinx:advertisementURL>)} \
            $component_text "\\1\n      <xilinx:vendorURL>https://github.com/GhlHub/dshot_host</xilinx:vendorURL>" \
            component_text
    }

    set fp [open $component_xml w]
    puts -nonewline $fp $component_text
    close $fp
}

if {![file exists $component_xml]} {
    create_project -in_memory dshot_ip_pack
    add_files -norecurse [glob -nocomplain [file join $ip_root hdl *.v]]
    set_property top dshot_axil_top [current_fileset]
    update_compile_order -fileset sources_1

    ipx::package_project \
        -root_dir $ip_root \
        -vendor user.org \
        -library user \
        -taxonomy /UserIP \
        -import_files \
        -set_current true

    set core [ipx::current_core]
    set_property name dshot_axil $core
    set_property display_name {DSHOT AXI-Lite Controller} $core
    set_property description {AXI-Lite controlled DSHOT controller with bidirectional eRPM receive, RX FIFO, and interrupt support.} $core
    set_property version 1.0 $core
    set_property core_revision 1 $core
    set_property company_url {https://github.com/GhlHub/dshot_host} $core
    set_property advertisement_url {https://github.com/GhlHub/dshot_host} $core
    set_property supported_families {artix7 Production kintex7 Production virtex7 Production zynq Production zynquplus Production} $core

    ipx::associate_bus_interfaces -busif s_axi -clock s_axi_aclk $core

    set clk_if [ipx::get_bus_interfaces s_axi_aclk -of_objects $core]
    if {[llength $clk_if] > 0} {
        set clk_param [ipx::get_bus_parameters FREQ_HZ -of_objects $clk_if]
        if {[llength $clk_param] == 0} {
            set clk_param [ipx::add_bus_parameter FREQ_HZ $clk_if]
        }
        set_property value 60000000 $clk_param
    }

    ipx::create_xgui_files $core
    ipx::update_checksums $core
    ipx::save_core $core
    close_project
}

ensure_productguide_metadata $component_xml

set core [ipx::open_core $component_xml]
set_property name dshot_axil $core
set_property display_name {DSHOT AXI-Lite Controller} $core
set_property description {AXI-Lite controlled DSHOT controller with bidirectional eRPM receive, RX FIFO, and interrupt support.} $core
set_property version 1.0 $core
set_property core_revision 1 $core
set_property company_url {https://github.com/GhlHub/dshot_host} $core
set_property advertisement_url {https://github.com/GhlHub/dshot_host} $core
set_property supported_families {artix7 Production kintex7 Production virtex7 Production zynq Production zynquplus Production} $core

set clk_if [ipx::get_bus_interfaces s_axi_aclk -of_objects $core]
if {[llength $clk_if] > 0} {
    set clk_param [ipx::get_bus_parameters FREQ_HZ -of_objects $clk_if]
    if {[llength $clk_param] == 0} {
        set clk_param [ipx::add_bus_parameter FREQ_HZ $clk_if]
    }
    set_property value 60000000 $clk_param
}

ipx::update_checksums $core
ipx::check_integrity $core
ipx::save_core $core
