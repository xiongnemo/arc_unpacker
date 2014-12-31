require_relative 'lzss_encoder'

# NSA archive
module NsaArchive
  NO_COMPRESSION = 0
  SPB_COMPRESSION = 1
  LZSS_COMPRESSION = 2

  def self.lzss_encoder
    LzssEncoder.new(initial_dictionary_pos: 239, reuse_compressed: true)
  end

  class Unpacker
    def unpack(arc_file, output_files, _options)
      table = read_table(arc_file)
      read_contents(arc_file, table, output_files)
    end

    private

    def read_table(arc_file)
      num_files,
      offset_to_files = arc_file.read(6).unpack('S>L>')
      fail ArcError, 'Bad offset to files' if offset_to_files > arc_file.size

      table = []
      num_files.times do
        e = {}

        e[:name] = arc_file.read_until_zero
        e[:compression_type],
        e[:origin],
        e[:size_compressed],
        e[:size_original] = arc_file.read(13).unpack('CL>L>L>')

        e[:origin] += offset_to_files
        table.push(e)

        if e[:origin] + e[:size_compressed] > arc_file.size
          fail ArcError, 'Bad offset to file'
        end
      end
      table
    end

    def read_contents(arc_file, table, output_files)
      table.each do |e|
        output_files.write do
          data = arc_file.peek(e[:origin]) do
            data = arc_file.read(e[:size_compressed])
            data = decompress(data, e[:compression_type])
            data
          end

          fail ArcError, 'Bad file size' unless data.length == e[:size_original]

          [e[:name], data]
        end
      end
    end

    def decompress(data, compression_type)
      case compression_type
      when SPB_COMPRESSION
        fail \
          ArcError,
          'SPB compression not supported! Please send samples to rr- on github.'
      when LZSS_COMPRESSION
        return NsaArchive.lzss_encoder.decode(data)
      else
        return data
      end
    end
  end

  class Packer
    def pack(arc_file, input_files, options)
      table_size = input_files.names.map { |n| n.length + 14 }.reduce(0, :+)
      offset_to_files = 6 + table_size
      arc_file.write([input_files.length, offset_to_files].pack('S>L>'))
      arc_file.write("\x00" * table_size)

      compression_type = options[:compression] || NO_COMPRESSION
      cur_data_origin = 0
      table_entries = []
      input_files.each do |file_name, data_original|
        data_compressed = compress(data_original, compression_type)
        data_size_original = data_original.length
        data_size_compressed = data_compressed.length

        arc_file.write(data_compressed)

        table_entries.push([
          file_name,
          cur_data_origin,
          data_size_original,
          data_size_compressed])

        cur_data_origin += data_size_compressed
      end

      arc_file.seek(6)
      table_entries.each do |file_name, data_origin, orig_size, compressed_size|
        arc_file.write(file_name.gsub('/', '\\'))
        arc_file.write("\0")

        arc_file.write([
          compression_type,
          data_origin,
          compressed_size,
          orig_size].pack('CL>L>L>'))
      end
    end

    private

    def compress(data, compression_type)
      case compression_type
      when SPB_COMPRESSION
        fail \
          ArcError,
          'SPB compression not supported! Please send samples to rr- on github.'
      when LZSS_COMPRESSION
        return NsaArchive.lzss_encoder.encode(data)
      else
        return data
      end
    end
  end
end
