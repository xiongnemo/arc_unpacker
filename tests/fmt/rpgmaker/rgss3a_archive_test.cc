#include "fmt/rpgmaker/rgss3a_archive.h"
#include "test_support/archive_support.h"
#include "test_support/catch.hh"
#include "test_support/file_support.h"

using namespace au;
using namespace au::fmt::rpgmaker;

TEST_CASE("Unpacking RGSS3A archives works")
{
    std::vector<std::shared_ptr<File>> expected_files
    {
        tests::stub_file("123.txt", "1234567890"_b),
        tests::stub_file("abc.txt", "abcdefghijklmnopqrstuvwxyz"_b),
    };

    Rgss3aArchive archive;
    auto actual_files = tests::unpack_to_memory(
        "tests/fmt/rpgmaker/files/rgss3a/test.rgss3a", archive);

    tests::compare_files(expected_files, actual_files, true);
}