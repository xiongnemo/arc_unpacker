require_relative '../../lib/ivory/mbl_archive'
require_relative '../test_helper'

# Unit tests for MblArchive
class MblArchiveTest < Test::Unit::TestCase
  def test_version2
    TestHelper.generic_pack_and_unpack_test(MblArchive.new, version: 2)
  end

  def test_sjis
    TestHelper.generic_sjis_names_test(MblArchive.new, version: 2)
  end

  def test_version1
    input_files = [{ file_name: 'short', data: 'whatever' }]

    output_files = TestHelper.pack_and_unpack(
      MblArchive.new,
      InputFilesMock.new(input_files),
      version: 1).files

    assert_equal(output_files, input_files)
  end

  def test_version1_too_long_names
    assert_raise(RuntimeError) do
      TestHelper.pack_and_unpack(
        MblArchive.new,
        InputFilesMock.new([{ file_name: 'long' * 10, data: 'whatever' }]),
        version: 1)
    end
  end
end
