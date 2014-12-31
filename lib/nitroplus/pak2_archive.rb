require_relative '../binary_io'
require 'zlib'

# PAK2 archive
module Pak2Archive
  MAGIC = "\x02\x00\x00\x00"
  # MAGIC1 = "\x01\x00\x00\x00"
  # MAGIC2 = "\x02\x00\x00\x00"
  # MAGIC3 = "\x03\x00\x00\x00"
  # MAGIC4 = "\x04\x00\x00\x00"

  class Unpacker
    def unpack(arc_file, output_files, _options)
      magic = arc_file.read(4)
      fail ArcError, 'Not a PAK archive' unless magic == MAGIC

      read_file_table(arc_file, output_files)
    end

    private

    def read_file_table(arc_file, output_files)
      file_count,
      table_size,
      compressed_table_size = arc_file.read(12).unpack('LLL')

      arc_file.seek(276)
      raw = Zlib.inflate(arc_file.read(compressed_table_size))
      raw = BinaryIO.from_string(raw)
      offset_to_files = arc_file.tell
      fail ArcError, 'Bad file table size' unless raw.length == table_size

      file_count.times do
        output_files.write { read_file(raw, arc_file, offset_to_files) }
      end
    end

    def read_file(raw_file_table, arc_file, offset_to_files)
      file_name = read_file_name(raw_file_table)

      data_origin,
      data_size_original,
      flags,
      data_size_compressed = raw_file_table.read(20).unpack('LLxxxxLL')

      arc_file.seek(data_origin + offset_to_files)
      if flags > 0
        data = Zlib.inflate(arc_file.read(data_size_compressed))
      else
        data = arc_file.read(data_size_original)
      end

      [file_name, data]
    end

    def read_file_name(arc_file)
      file_name_length = arc_file.read(4).unpack('L')[0]
      file_name = arc_file.read(file_name_length)
      file_name.force_encoding('sjis').encode('utf-8')
    rescue
      file_name
    end
  end
end
