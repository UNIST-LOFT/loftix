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

# build:
#     guix build --no-substitutes {{guix_spec}}
