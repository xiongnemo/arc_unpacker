#include "fmt/touhou/pak1_archive_decoder.h"
#include "err.h"
#include "fmt/touhou/pak1_audio_archive_decoder.h"
#include "fmt/touhou/pak1_image_archive_decoder.h"
#include "io/buffered_io.h"
#include "util/range.h"

using namespace au;
using namespace au::fmt::touhou;

namespace
{
    struct TableEntry final
    {
        std::string name;
        u32 offset;
        u32 size;
    };

    using Table = std::vector<std::unique_ptr<TableEntry>>;
}

static void decrypt(bstr &buffer, u8 a, u8 b, u8 delta)
{
    for (auto i : util::range(buffer.size()))
    {
        buffer[i] ^= a;
        a += b;
        b += delta;
    }
}

static std::unique_ptr<File> read_file(io::IO &arc_io, const TableEntry &entry)
{
    std::unique_ptr<File> file(new File);
    file->name = entry.name;

    arc_io.seek(entry.offset);
    auto data = arc_io.read(entry.size);

    if (file->name.find("musicroom.dat") != std::string::npos)
    {
        decrypt(data, 0x5C, 0x5A, 0x3D);
        file->change_extension(".txt");
    }
    else if (file->name.find(".sce") != std::string::npos)
    {
        decrypt(data, 0x63, 0x62, 0x42);
        file->change_extension(".txt");
    }
    else if (file->name.find("cardlist.dat") != std::string::npos)
    {
        decrypt(data, 0x60, 0x61, 0x41);
        file->change_extension(".txt");
    }

    file->io.write(data);
    return file;
}

static std::unique_ptr<io::BufferedIO> read_raw_table(
    io::IO &arc_io, size_t file_count)
{
    size_t table_size = file_count * 0x6C;
    if (table_size > arc_io.size() - arc_io.tell())
        throw err::RecognitionError();
    if (table_size > file_count * (0x64 + 4 + 4))
        throw err::RecognitionError();
    auto buffer = arc_io.read(table_size);
    decrypt(buffer, 0x64, 0x64, 0x4D);
    return std::unique_ptr<io::BufferedIO>(new io::BufferedIO(buffer));
}

static Table read_table(io::IO &arc_io)
{
    u16 file_count = arc_io.read_u16_le();
    if (file_count == 0 && arc_io.size() != 6)
        throw err::RecognitionError();
    auto table_io = read_raw_table(arc_io, file_count);
    Table table;
    table.reserve(file_count);
    for (auto i : util::range(file_count))
    {
        std::unique_ptr<TableEntry> entry(new TableEntry);
        entry->name = table_io->read_to_zero(0x64).str();
        entry->size = table_io->read_u32_le();
        entry->offset = table_io->read_u32_le();
        if (entry->offset + entry->size > arc_io.size())
            throw err::BadDataOffsetError();
        table.push_back(std::move(entry));
    }
    return table;
}

struct Pak1ArchiveDecoder::Priv final
{
    Pak1ImageArchiveDecoder image_archive_decoder;
    Pak1AudioArchiveDecoder audio_archive_decoder;
};

Pak1ArchiveDecoder::Pak1ArchiveDecoder() : p(new Priv)
{
    add_decoder(&p->image_archive_decoder);
    add_decoder(&p->audio_archive_decoder);
}

Pak1ArchiveDecoder::~Pak1ArchiveDecoder()
{
}

bool Pak1ArchiveDecoder::is_recognized_internal(File &arc_file) const
{
    try
    {
        read_table(arc_file.io);
        return true;
    }
    catch (...)
    {
        return false;
    }
}

void Pak1ArchiveDecoder::unpack_internal(File &arc_file, FileSaver &saver) const
{
    auto table = read_table(arc_file.io);
    for (auto &entry : table)
        saver.save(read_file(arc_file.io, *entry));
}

static auto dummy = fmt::Registry::add<Pak1ArchiveDecoder>("th/pak1");