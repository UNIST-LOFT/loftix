# import "../../Justfile"
import? 'dev.justfile'

poc_input := env("POC_INPUT")
poc_dir := env("POC_DIR", "poc")
binary := env("BINARY")
guix_spec := env("GUIX_SPEC")
test_cmd := env("TEST_CMD")
patch_source := source_directory() + "/brpatch.c"

# default:
#     just --list

build-sdfuzz:
    bash sdfuzz.sh all

run-sdfuzz:
    timeout 12h bash sdfuzz.sh fuzz

build-trigfuzz:
    bash trigfuzz.sh all

run-trigfuzz:
    timeout 12h bash trigfuzz.sh fuzz
