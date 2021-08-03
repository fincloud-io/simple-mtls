#!/usr/bin/env bash
# Read and parse simple INI file

# Get INI section
ReadINISections(){
  local filename="$1"
  gawk '{ if ($1 ~ /^\[/) section=tolower(gensub(/\[(.+)\]/,"\\1",1,$1)); configuration[section]=1 } END {for (key in configuration) { print key} }' ${filename}
}

# Get/Set all INI sections
GetINISections(){
  local filename="$1"

  sections="$(ReadINISections $filename)"
  for section in $sections; do
    array_name="configuration_${section}"
    declare -g -A "${array_name}"
  done
  eval $(gawk -F= '{
                    if ($1 ~ /^\[/)
                      section=tolower(gensub(/\[(.+)\]/,"\\1",1,$1))
                    else if ($1 !~ /^$/ && $1 !~ /^;/) {
                      gsub(/^[ \t]+|[ \t]+$/, "", $1);
                      gsub(/[\[\]]/, "", $1);
                      gsub(/^[ \t]+|[ \t]+$/, "", $2);
                      if (configuration[section][$1] == "")
                        configuration[section][$1]=$2
                      else
                        configuration[section][$1]=configuration[section][$1]" "$2}
                    }
                    END {
                      for (section in configuration)
                        for (key in configuration[section]) {
                          section_name = section
                          gsub( "-", "_", section_name)
                          print "configuration_" section_name "[\""key"\"]=\""configuration[section][key]"\";"
                        }
                    }' ${filename}
        )


}