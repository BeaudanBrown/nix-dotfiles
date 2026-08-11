#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/un.h>
#include <unistd.h>

#include <atomic>
#include <cerrno>
#include <csignal>
#include <cstdint>
#include <cstring>
#include <exception>
#include <iostream>
#include <string>
#include <vector>

#include "moonshine-cpp.h"

namespace {

std::atomic<bool> stopping{false};
int listener_fd = -1;

void handle_signal(int) {
  stopping = true;
  if (listener_fd >= 0) {
    close(listener_fd);
    listener_fd = -1;
  }
}

bool write_all(int fd, const std::string &value) {
  const char *cursor = value.data();
  std::size_t remaining = value.size();
  while (remaining > 0) {
    const ssize_t written = send(fd, cursor, remaining, MSG_NOSIGNAL);
    if (written < 0) {
      if (errno == EINTR) {
        continue;
      }
      return false;
    }
    cursor += written;
    remaining -= static_cast<std::size_t>(written);
  }
  return true;
}

std::string transcript_text(const moonshine::Transcript &transcript) {
  std::string result;
  for (const auto &line : transcript.lines) {
    if (line.text.empty()) {
      continue;
    }
    if (!result.empty() && result.back() != ' ') {
      result.push_back(' ');
    }
    result += line.text;
  }
  return result;
}

void transcribe_client(int client_fd, moonshine::Transcriber &transcriber) {
  try {
    auto stream = transcriber.createStream(0.5);
    stream.start();

    std::vector<std::uint8_t> bytes(8192);
    std::vector<float> samples;
    samples.reserve(bytes.size() / 2);
    bool have_pending_byte = false;
    std::uint8_t pending_byte = 0;

    while (true) {
      const ssize_t count = read(client_fd, bytes.data(), bytes.size());
      if (count == 0) {
        break;
      }
      if (count < 0) {
        if (errno == EINTR) {
          continue;
        }
        throw std::runtime_error(std::string("failed to read audio: ") +
                                 std::strerror(errno));
      }

      samples.clear();
      std::size_t index = 0;
      if (have_pending_byte && count > 0) {
        const std::uint16_t raw = static_cast<std::uint16_t>(pending_byte) |
                                  (static_cast<std::uint16_t>(bytes[0]) << 8);
        samples.push_back(static_cast<std::int16_t>(raw) / 32768.0f);
        have_pending_byte = false;
        index = 1;
      }

      for (; index + 1 < static_cast<std::size_t>(count); index += 2) {
        const std::uint16_t raw = static_cast<std::uint16_t>(bytes[index]) |
                                  (static_cast<std::uint16_t>(bytes[index + 1])
                                   << 8);
        samples.push_back(static_cast<std::int16_t>(raw) / 32768.0f);
      }
      if (index < static_cast<std::size_t>(count)) {
        pending_byte = bytes[index];
        have_pending_byte = true;
      }
      if (!samples.empty()) {
        stream.addAudio(samples, 16000);
      }
    }

    stream.stop();
    const auto transcript =
        stream.updateTranscription(moonshine::Stream::FLAG_FORCE_UPDATE);
    const std::string text = transcript_text(transcript);
    if (text.empty()) {
      write_all(client_fd, "ERROR\nempty transcript\n");
      return;
    }
    write_all(client_fd, "OK\n" + text + "\n");
  } catch (const std::exception &error) {
    std::cerr << "transcription failed: " << error.what() << '\n';
    write_all(client_fd, std::string("ERROR\n") + error.what() + "\n");
  }
}

int create_listener(const std::string &socket_path) {
  if (socket_path.size() >= sizeof(sockaddr_un::sun_path)) {
    throw std::runtime_error("socket path is too long");
  }

  const int fd = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);
  if (fd < 0) {
    throw std::runtime_error(std::string("failed to create socket: ") +
                             std::strerror(errno));
  }

  sockaddr_un address{};
  address.sun_family = AF_UNIX;
  std::strncpy(address.sun_path, socket_path.c_str(),
               sizeof(address.sun_path) - 1);
  unlink(socket_path.c_str());

  const mode_t previous_umask = umask(0077);
  const int bind_result =
      bind(fd, reinterpret_cast<sockaddr *>(&address), sizeof(address));
  umask(previous_umask);
  if (bind_result < 0) {
    const std::string message = std::strerror(errno);
    close(fd);
    throw std::runtime_error("failed to bind socket: " + message);
  }
  if (chmod(socket_path.c_str(), 0600) < 0) {
    const std::string message = std::strerror(errno);
    close(fd);
    unlink(socket_path.c_str());
    throw std::runtime_error("failed to secure socket: " + message);
  }
  if (listen(fd, 1) < 0) {
    const std::string message = std::strerror(errno);
    close(fd);
    unlink(socket_path.c_str());
    throw std::runtime_error("failed to listen: " + message);
  }
  return fd;
}

}  // namespace

int main(int argc, char **argv) {
  if (argc != 3) {
    std::cerr << "usage: moonshine-stt-daemon MODEL_DIR SOCKET_PATH\n";
    return 2;
  }

  const std::string model_path = argv[1];
  const std::string socket_path = argv[2];
  signal(SIGINT, handle_signal);
  signal(SIGTERM, handle_signal);

  try {
    std::cerr << "loading Moonshine Small Streaming model\n";
    const moonshine::Options options = {
        {"vad_threshold", "0.3"},
        {"vad_window_duration", "1.0"},
        {"vad_max_segment_duration", "30"},
    };
    moonshine::Transcriber transcriber(
        model_path, moonshine::ModelArch::SMALL_STREAMING, 0.5, "", options);
    listener_fd = create_listener(socket_path);
    std::cerr << "listening on " << socket_path << '\n';

    while (!stopping) {
      const int client_fd = accept4(listener_fd, nullptr, nullptr, SOCK_CLOEXEC);
      if (client_fd < 0) {
        if (stopping || errno == EINTR || errno == EBADF) {
          continue;
        }
        std::cerr << "accept failed: " << std::strerror(errno) << '\n';
        continue;
      }
      transcribe_client(client_fd, transcriber);
      close(client_fd);
    }

    if (listener_fd >= 0) {
      close(listener_fd);
    }
    unlink(socket_path.c_str());
    return 0;
  } catch (const std::exception &error) {
    std::cerr << "moonshine-stt-daemon: " << error.what() << '\n';
    if (listener_fd >= 0) {
      close(listener_fd);
    }
    unlink(socket_path.c_str());
    return 1;
  }
}
