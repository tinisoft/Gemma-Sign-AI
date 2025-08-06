import 'dart:typed_data';

class AudioUtils {
  /// The VAD package provides audio as a `List<double>` where each sample is
  /// between -1.0 and 1.0. This function converts that to 16-bit PCM and
  /// prepends the necessary 44-byte WAV header.
  static Uint8List encodeToWav(List<double> samples, int sampleRate) {
    int numSamples = samples.length;
    int numChannels = 1; // Mono
    int bitDepth = 16;
    int byteRate = sampleRate * numChannels * (bitDepth ~/ 8);

    // Total size of the PCM data in bytes
    int pcmDataSize = numSamples * numChannels * (bitDepth ~/ 8);

    // The total file size, including the header (44 bytes)
    int fileSize = pcmDataSize + 44;

    // Create a ByteData buffer for the entire file.
    final byteData = ByteData(fileSize);

    // --- WAV HEADER ---

    // RIFF chunk descriptor
    byteData.setUint8(0, 0x52); // 'R'
    byteData.setUint8(1, 0x49); // 'I'
    byteData.setUint8(2, 0x46); // 'F'
    byteData.setUint8(3, 0x46); // 'F'
    byteData.setUint32(4, fileSize - 8, Endian.little); // ChunkSize
    byteData.setUint8(8, 0x57); // 'W'
    byteData.setUint8(9, 0x41); // 'A'
    byteData.setUint8(10, 0x56); // 'V'
    byteData.setUint8(11, 0x45); // 'E'

    // "fmt " sub-chunk
    byteData.setUint8(12, 0x66); // 'f'
    byteData.setUint8(13, 0x6d); // 'm'
    byteData.setUint8(14, 0x74); // 't'
    byteData.setUint8(15, 0x20); // ' '
    byteData.setUint32(16, 16, Endian.little); // Subchunk1Size (16 for PCM)
    byteData.setUint16(20, 1, Endian.little); // AudioFormat (1 for PCM)
    byteData.setUint16(22, numChannels, Endian.little); // NumChannels
    byteData.setUint32(24, sampleRate, Endian.little); // SampleRate
    byteData.setUint32(28, byteRate, Endian.little); // ByteRate
    byteData.setUint16(
      32,
      numChannels * (bitDepth ~/ 8),
      Endian.little,
    ); // BlockAlign
    byteData.setUint16(34, bitDepth, Endian.little); // BitsPerSample

    // "data" sub-chunk
    byteData.setUint8(36, 0x64); // 'd'
    byteData.setUint8(37, 0x61); // 'a'
    byteData.setUint8(38, 0x74); // 't'
    byteData.setUint8(39, 0x61); // 'a'
    byteData.setUint32(40, pcmDataSize, Endian.little); // Subchunk2Size

    // --- PCM AUDIO DATA ---
    int offset = 44;
    for (int i = 0; i < numSamples; i++) {
      // Convert float sample to 16-bit signed integer
      final sample = (samples[i].clamp(-1.0, 1.0) * 32767.0).toInt();
      byteData.setInt16(offset, sample, Endian.little);
      offset += 2;
    }

    // Return the complete WAV file as a byte list
    return byteData.buffer.asUint8List();
  }
}
