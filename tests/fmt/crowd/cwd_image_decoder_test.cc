#include "fmt/crowd/cwd_image_decoder.h"
#include "test_support/catch.h"
#include "test_support/decoder_support.h"
#include "test_support/file_support.h"
#include "test_support/image_support.h"

using namespace au;
using namespace au::fmt::crowd;

static const std::string dir = "tests/fmt/crowd/files/cwd/";

static void do_test(
    const std::string &input_path, const std::string &expected_path)
{
    const CwdImageDecoder decoder;
    const auto input_file = tests::zlib_file_from_path(dir + input_path);
    const auto expected_file = tests::file_from_path(dir + expected_path);
    const auto actual_image = tests::decode(decoder, *input_file);
    tests::compare_images(*expected_file, actual_image);
}

TEST_CASE("Crowd CWD images", "[fmt]")
{
    do_test("306-301-zlib.cwd", "306-301-out.png");
}
