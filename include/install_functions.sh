#!/usr/bin/env bash
# Armored Turtle Automated Filament Changer
#
# Copyright (C) 2024-2026 Armored Turtle
#
# This file may be distributed under the terms of the GNU GPLv3 license.

check_dirs() {
  # Debugging: Check if the directory exists
  if [ ! -d "${afc_path}/include/" ]; then
    echo "Directory ${afc_path}/include/ does not exist."
    exit 1
  fi

  # Debugging: Check if there are any files in the directory
  if [ -z "$(ls -A "${afc_path}/include/")" ]; then
    echo "No files found in ${afc_path}/include/"
    exit 1
  fi
}

link_extensions() {
  # Function to link AFC extensions to Klipper.
  # Uses the global variables:
  #   - KLIPPER_DIR: The path to the Klipper installation.
  #   - AFC_PATH: The path to the AFC Klipper Add-On repository.
  local message

  if [ -d "${klipper_dir}/klippy/extras" ]; then
    for extension in "${afc_path}"/extras/AFC*.py; do
      ln -sf "${afc_path}/extras/$(basename "${extension}")" "${klipper_dir}/klippy/extras/$(basename "${extension}")"
    done
  else
    export message="AFC Klipper extensions not installed; Klipper extras directory not found."
  fi
}

unlink_extensions() {
  # Function to unlink AFC extensions from Klipper.
  # Uses the global variables:
  #   - KLIPPER_PATH: The path to the Klipper installation.
  #   - AFC_PATH: The path to the AFC Klipper Add-On repository.
  if [ -d "${klipper_dir}/klippy/extras" ]; then
    for extension in "${afc_path}"/extras/*.py; do
      rm -f "${klipper_dir}/klippy/extras/$(basename "${extension}")"
    done
  else
    print_msg ERROR "AFC Klipper extensions not uninstalled; Klipper extras directory not found."
    exit 1
  fi
}

template_unit_files() {
  local input_file="$1"
  local output_file="$2"

  case "${installation_type}" in
    "HTLF") MCU="${htlf_board_type}" ;;
    "BoxTurtle (4-Lane)") MCU="AFC" ;;
    "NightOwl") MCU="ERB" ;;
    *) MCU="UNKNOWN" ;;  # Optional: fallback
  esac

  export INSTALL_TYPE="${installation_type}"
  export MCU

  envsubst < "${input_file}" > "${output_file}"
}

copy_unit_files() {
  case "$installation_type" in
  "ViViD")
    safe_copy "${afc_path}/templates/AFC_Vivid_1.cfg" "${afc_config_dir}/AFC_Vivid_1.cfg"
    safe_copy "${afc_path}/templates/AFC_Hardware-AFC.cfg" "${afc_config_dir}/AFC_Hardware.cfg"
    safe_copy "${afc_path}/config/mcu/Vivid.cfg" "${afc_config_dir}/mcu/Vivid_1.cfg"
    ;;
  "BoxTurtle (4-Lane)")
    safe_copy "${afc_path}/config/mcu/AFC_Lite.cfg" "${afc_config_dir}/mcu/AFC_Lite.cfg"
    safe_copy "${afc_path}/templates/AFC_Hardware-AFC.cfg" "${afc_config_dir}/AFC_Hardware.cfg"
    safe_copy "${afc_path}/templates/AFC_Turtle_1.cfg" "${afc_config_dir}/AFC_${boxturtle_name}.cfg"
    ;;

  "BoxTurtle (8-Lane)")
    safe_copy "${afc_path}/config/mcu/AFC_Pro.cfg" "${afc_config_dir}/mcu/AFC_Pro.cfg"
    safe_copy "${afc_path}/templates/AFC_Hardware-AFC.cfg" "${afc_config_dir}/AFC_Hardware.cfg"
    safe_copy "${afc_path}/templates/AFC_Pro_Turtle_1.cfg" "${afc_config_dir}/AFC_${boxturtle_name}.cfg"
    ;;

  "NightOwl")
    safe_copy "${afc_path}/config/mcu/ERB_2.0.cfg" "${afc_config_dir}/mcu/ERB_2.0.cfg"
    safe_copy "${afc_path}/templates/AFC_Hardware-NightOwl.cfg" "${afc_config_dir}/AFC_Hardware.cfg"
    safe_copy "${afc_path}/templates/AFC_NightOwl_1.cfg" "${afc_config_dir}/AFC_NightOwl_1.cfg"
    ;;

  "HTLF")
    local board_type="$htlf_board_type"
    safe_copy "${afc_path}/config/mcu/HTLF_${board_type}.cfg" "${afc_config_dir}/mcu/"
    [[ "$board_type" == "MMB_1.0" || "$board_type" == "MMB_1.1" ]] && board_type="MMB"
    safe_copy "${afc_path}/templates/AFC_HTLF_1-${board_type}.cfg" "${afc_config_dir}/AFC_${board_type}_${boxturtle_name}.cfg"
    safe_copy "${afc_path}/templates/AFC_Hardware-HTLF.cfg" "${afc_config_dir}/AFC_Hardware.cfg"
    ;;

  "QuattroBox")
    safe_copy "${afc_path}/templates/AFC_Hardware-QuattroBox.cfg" "${afc_config_dir}/AFC_Hardware.cfg"
    safe_copy "${afc_path}/templates/qb_macros/Eject_buttons.cfg" "${afc_config_dir}/macros/Eject_buttons.cfg"
    if [ "${qb_motor_type}" == "NEMA_14" ]; then
      safe_copy "${afc_path}/templates/AFC_QuattroBox_14.cfg" "${afc_config_dir}/AFC_QuattroBox_1.cfg"
      if [ "${qb_board_type}" == "MMB_1.0" ]; then
        safe_copy "${afc_path}/config/mcu/MMB_1.0_QB.cfg" "${afc_config_dir}/mcu/"
        sed -i "s/include mcu\/MMB_QB.cfg/include mcu\/MMB_1.0_QB.cfg/g" "${afc_config_dir}/AFC_QuattroBox_1.cfg"
      elif [ "${qb_board_type}" == "MMB_1.1" ]; then
        safe_copy "${afc_path}/config/mcu/MMB_1.1_QB.cfg" "${afc_config_dir}/mcu/"
        sed -i "s/include mcu\/MMB_QB.cfg/include mcu\/MMB_1.1_QB.cfg/g" "${afc_config_dir}/AFC_QuattroBox_1.cfg"
      elif [ "${qb_board_type}" == "MMB_2.0" ]; then
        safe_copy "${afc_path}/config/mcu/MMB_2.0_QB.cfg" "${afc_config_dir}/mcu/"
        sed -i "s/include mcu\/MMB_QB.cfg/include mcu\/MMB_2.0_QB.cfg/g" "${afc_config_dir}/AFC_QuattroBox_1.cfg"
      fi
    elif [ "${qb_motor_type}" == "NEMA_17" ]; then
      safe_copy "${afc_path}/templates/AFC_QuattroBox_17.cfg" "${afc_config_dir}/AFC_QuattroBox_1.cfg"
      if [ "${qb_board_type}" == "MMB_1.0" ]; then
        safe_copy "${afc_path}/config/mcu/MMB_1.0_QB.cfg" "${afc_config_dir}/mcu/"
        sed -i "s/include mcu\/MMB_QB.cfg/include mcu\/MMB_1.0_QB.cfg/g" "${afc_config_dir}/AFC_QuattroBox_1.cfg"
      elif [ "${qb_board_type}" == "MMB_1.1" ]; then
        safe_copy "${afc_path}/config/mcu/MMB_1.1_QB.cfg" "${afc_config_dir}/mcu/"
        sed -i "s/include mcu\/MMB_QB.cfg/include mcu\/MMB_1.1_QB.cfg/g" "${afc_config_dir}/AFC_QuattroBox_1.cfg"
      elif [ "${qb_board_type}" == "MMB_2.0" ]; then
        safe_copy "${afc_path}/config/mcu/MMB_2.0_QB.cfg" "${afc_config_dir}/mcu/"
        sed -i "s/include mcu\/MMB_QB.cfg/include mcu\/MMB_2.0_QB.cfg/g" "${afc_config_dir}/AFC_QuattroBox_1.cfg"
      fi
    fi
    ;;

  "OpenAMS")
    safe_copy "${afc_path}/templates/AFC_Hardware-AFC.cfg" "${afc_config_dir}/AFC_Hardware.cfg"
    safe_copy "${afc_path}/templates/AFC_AMS_1.cfg" "${afc_config_dir}/AFC_AMS_1.cfg"
    ;;

  "EMU")
    safe_copy "${afc_path}/templates/AFC_Hardware-AFC.cfg" "${afc_config_dir}/AFC_Hardware.cfg"
    generate_emu_config "$boxturtle_name" "$emu_num_lanes"
    ;;

esac
}

generate_emu_config() {
  local unit_name="$1"
  local num_lanes="$2"
  local output_file="${afc_config_dir}/AFC_${unit_name}.cfg"
  local mcu_output_file="${afc_config_dir}/mcu/EMU_${unit_name}.cfg"

  mkdir -p "${afc_config_dir}/mcu"

  # Build comma-separated MCU list for board_pins
  local mcu_list=""
  for ((i=1; i<=num_lanes; i++)); do
    if [ "$i" -eq 1 ]; then
      mcu_list="${unit_name}_lane${i}"
    else
      mcu_list="${mcu_list}, ${unit_name}_lane${i}"
    fi
  done

  # Write MCU board_pins file
  cat > "${mcu_output_file}" <<EOF
[board_pins ${unit_name}]
mcu: ${mcu_list}
aliases:
    MOT_UART=PA15,
    MOT_STEP=PD0,
    MOT_DIR=PD1,
    MOT_EN=PD2,
    MOT_DIAG=,

    RGB=PD3,

    TRG=PB7,
    LOAD=PB5,

    BUFFER_ADV=PB8,
    BUFFER_TRL=PB9,

    TH=PA3,

    FAN=PA0,

    BUTTON=PB6,

    TEMP_SCL=PB3,
    TEMP_SCA=PB4
EOF

  # Write unit config header
  cat > "${output_file}" <<EOF
[include mcu/EMU_${unit_name}.cfg]

EOF

  # Write per-lane MCU sections
  for ((i=1; i<=num_lanes; i++)); do
    cat >> "${output_file}" <<EOF
[mcu ${unit_name}_lane${i}]
canbus_uuid: <replace with your can UUID>
#serial: <replace with your /dev/serial/by-id/...> and comment out canbus_uuid above

[temperature_sensor ${unit_name}_lane${i}]
sensor_type: temperature_mcu
sensor_mcu: ${unit_name}_lane${i}

EOF
  done

  # Write AFC_EMU unit section
  cat >> "${output_file}" <<EOF
[AFC_EMU ${unit_name}]
hub: ${unit_name}_HUB
extruder: extruder
buffer: ${unit_name}_buffer
long_moves_speed: 300
long_moves_accel: 300

EOF

  # Write per-lane AFC_stepper, tmc, button, temp, fan, and led sections
  for ((i=1; i<=num_lanes; i++)); do
    cat >> "${output_file}" <<EOF
[AFC_stepper lane${i}]
unit: ${unit_name}:${i}
step_pin: ${unit_name}_lane${i}:MOT_STEP
dir_pin: ${unit_name}_lane${i}:MOT_DIR
enable_pin: !${unit_name}_lane${i}:MOT_EN
microsteps: 16
rotation_distance: 22.7574
gear_ratio: 1:1
dist_hub: 2000
park_dist: 10
led_index: ${unit_name}_Indicator_${i}:1
led_spool_index: ${unit_name}_Indicator_${i}:2
prep: ^!${unit_name}_lane${i}:TRG
load: ^${unit_name}_lane${i}:LOAD

[tmc2209 AFC_stepper lane${i}]
uart_pin: ${unit_name}_lane${i}:MOT_UART
uart_address: 0
run_current: 0.8
sense_resistor: 0.110

[AFC_button lane${i}]
pin: ^!${unit_name}_lane${i}:BUTTON

[temperature_sensor lane${i}]
sensor_type: BME280
i2c_address: 118
i2c_mcu: ${unit_name}_lane${i}
i2c_software_scl_pin: ${unit_name}_lane${i}:TEMP_SCL
i2c_software_sda_pin: ${unit_name}_lane${i}:TEMP_SCA

[controller_fan ${unit_name}_fan_lane${i}]
pin: ${unit_name}_lane${i}:FAN
max_power: 1
kick_start_time: 0.5
stepper: AFC_stepper lane${i}

[AFC_led ${unit_name}_Indicator_${i}]
pin: ${unit_name}_lane${i}:RGB
chain_count: 2
color_order: GRBW
initial_RED: 0.0
initial_GREEN: 0.0
initial_BLUE: 0.0
initial_WHITE: 0.0

EOF
  done

  # Write buffer section (uses lane1 for buffer advance/trailing pins)
  cat >> "${output_file}" <<EOF
[AFC_buffer ${unit_name}_buffer]
advance_pin: ${unit_name}_lane1:BUFFER_ADV
trailing_pin: ${unit_name}_lane1:BUFFER_TRL
multiplier_high: 1.15
multiplier_low: 0.90

# EMU hub defaults to virtual (no sensor). To use a physical hub sensor:
#  - Replace "virtual" with the actual sensor pin
#  - Update dist_hub in each AFC_stepper section to the PTFE length between
#    the load sensor and hub sensor
#  - Remove/comment out the \`use_dist_hub: True\` line
[AFC_hub ${unit_name}_HUB]
afc_bowden_length: 2000
hub_clear_move_dis: 5
switch_pin: virtual
use_dist_hub: True
EOF
}

install_afc() {
  # Link the python extensions
  link_extensions
  if [ "$installation_type" != "OpenAMS" ]; then
    copy_config
  else
    copy_openams_config
  fi
  copy_unit_files
  # Add our extensions to the klipper gitignore
  if [ "$git_install" == "True" ]; then
    if [ "$test_mode" == "False" ]; then
      exclude_from_klipper_git
    fi
  else
    print_msg INFO "Skipping exclude from klipper git for git installations."
  fi
  # Include the AFC configuration files if selected
  if [ "$afc_includes" == True ]; then
    manage_include "${printer_config_dir}/printer.cfg" "add"
  fi
  # Update selected configuration values
  update_config_value "${afc_file}" "park" "${park_macro}"
  update_config_value "${afc_file}" "poop" "${poop_macro}"
  update_config_value "${afc_file}" "form_tip" "${tip_forming}"
  update_config_value "${afc_file}" "tool_cut" "${toolhead_cutter}"
  update_config_value "${afc_file}" "hub_cut" "${hub_cutter}"
  update_config_value "${afc_file}" "kick" "${kick_macro}"
  update_config_value "${afc_file}" "wipe" "${wipe_macro}"

  if [ "$toolhead_sensor" == "Sensor" ]; then
    update_switch_pin "${afc_config_dir}/AFC_Hardware.cfg" "${toolhead_sensor_pin}"
  elif [ "$toolhead_sensor" == "Ramming" ]; then
    if [ "$installation_type" != "OpenAMS" ]; then
      update_switch_pin "${afc_config_dir}/AFC_Hardware.cfg" "buffer"
    elif [ "$installation_type" == "OpenAMS" ]; then
      update_switch_pin "${afc_config_dir}/AFC_Hardware.cfg" "AMS_extruder"
    fi
  fi

  # When using Boxturtle as Installation Type then insert selected buffer configuration
  # NightOwl uses Turtleneck as default for now
  if [ "$installation_type" == "BoxTurtle (4-Lane)" ] || [ "$installation_type" == "BoxTurtle (8-Lane)" ]; then
    # Make sure the unit name is correct per the user choice
    if [ "$boxturtle_name" != "Turtle_1" ]; then
      find "$afc_config_dir" -type f -exec sed -i "s/Turtle_1/$boxturtle_name/g" {} +
    fi
    if [ "$buffer_type" == "TurtleNeck" ]; then
      query_tn_pins "TN" "$boxturtle_name"
      append_buffer_config "TurtleNeck" "$tn_advance_pin" "$tn_trailing_pin" "$boxturtle_name"
      add_buffer_to_extruder "${afc_config_dir}/AFC_${boxturtle_name}.cfg" "${boxturtle_name}" "${boxturtle_name}"
    elif [ "$buffer_type" == "TurtleNeckV2" ]; then
      append_buffer_config "TurtleNeckV2" "" "" "$boxturtle_name"
      add_buffer_to_extruder "${afc_config_dir}/AFC_${boxturtle_name}.cfg" "${boxturtle_name}" "${boxturtle_name}"
    fi
  fi
  check_and_append_prep "${afc_config_dir}/AFC.cfg"
  replace_varfile_path "${afc_config_dir}/AFC.cfg"
  if [ "$git_install" == "True" ]; then
    update_moonraker_config
  fi

  export message
  export files_updated_or_installed="True"

  # Final step should be displaying any messages and exit cleanly.
  message="""
- AFC Configuration updated with selected options at ${afc_file}

- AFC-Klipper-Add-On python extensions installed to ${klipper_dir}/klippy/extras/
"""

if [ "$installation_type" == "BoxTurtle (4-Lane)" ] || [ "$installation_type" == "BoxTurtle (8-Lane)" ]; then
  message+="""
- Ensure you enter either your CAN bus or serial information in the ${afc_config_dir}/AFC_${boxturtle_name}.cfg file
  """
elif [ "$installation_type" == "NightOwl" ]; then
  message+="""
- Ensure you enter either your CAN bus or serial information in the ${afc_config_dir}/AFC_NightOwl_1.cfg file
  """
elif [ "$installation_type" == "HTLF" ]; then
  message+="""
- Ensure you enter either your CAN bus or serial information in the ${afc_config_dir}/AFC_${htlf_board_type}_${boxturtle_name}_1.cfg file.

- Ensure you modify the ${afc_config_dir}/AFC_${htlf_board_type}_${boxturtle_name}_1.cfg file to select the proper rotation distance
  and gear ratio for your stepper motors.

- Ensure you update any necessary buffer information in the ${afc_config_dir}/AFC_Hardware.cfg file
  """
elif [ "$installation_type" == "QuattroBox" ]; then
  message+="""
- You must update the ${afc_config_dir}/AFC_Hardware.cfg file to reference the proper buffer configuration and pins.

- Ensure you enter either your CAN bus or serial information in the ${afc_config_dir}/AFC_QuattroBox_1.cfg file
  """
elif [ "$installation_type" == "OpenAMS" ]; then
  message+="""
- Review and update the ${afc_config_dir}/AFC_AMS_1.cfg file for your AMS unit settings.

- Ensure OpenAMS is properly installed and configured per their instructions.
  """
elif [ "$installation_type" == "ViViD" ]; then
  message+="""
- Ensure you enter your serial information in the ${afc_config_dir}/AFC_Vivid_1.cfg file

- Review the ${afc_config_dir}/AFC_Hardware.cfg file to reference the proper buffer configuration and pins.
  """
elif [ "$installation_type" == "EMU" ]; then
  message+="""
- Ensure you enter either your CAN bus or serial information for each lane in the ${afc_config_dir}/AFC_${boxturtle_name}.cfg file

- The MCU board_pins configuration is at ${afc_config_dir}/mcu/EMU_${boxturtle_name}.cfg
  """
fi

if [ "$buffer_type" == "TurtleNeckV2" ]; then
  message+="""
- Ensure you add the correct serial information to the ${afc_config_dir}/mcu/TurtleNeckv2.cfg file
  """
fi

message+="""
You may now quit the script or return to the main menu.

${RED}If you would like to add any additional units, please restart the script to ensure the
current units are loaded correctly.${NC}
"""

}