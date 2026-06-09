#include "desktop_core.h"

#include <cerrno>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <sstream>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>
#include <vector>

namespace v2ray_box {
namespace {

std::string ShellQuote(const std::string& value) {
  std::string quoted = "'";
  for (const char ch : value) {
    if (ch == '\'') {
      quoted += "'\\''";
    } else {
      quoted += ch;
    }
  }
  quoted += "'";
  return quoted;
}

void KillOrphanCoreProcesses(const std::string& config_path) {
  const std::string cmd =
      "pkill -f " + ShellQuote(config_path) + " >/dev/null 2>&1";
  std::system(cmd.c_str());
  usleep(200000);
}

void KillProcessOnPort(int port) {
  if (port <= 0) {
    return;
  }
  const std::string cmd =
      "fuser -k " + std::to_string(port) + "/tcp >/dev/null 2>&1";
  std::system(cmd.c_str());
  usleep(100000);
}

constexpr const char* kXrayName = "xray";
constexpr const char* kSingboxName = "sing-box";

bool IsExecutable(const std::string& path) {
  return access(path.c_str(), X_OK) == 0;
}

bool FileExists(const std::string& path) {
  struct stat st {};
  return stat(path.c_str(), &st) == 0 && S_ISREG(st.st_mode);
}

void AppendUnique(std::vector<std::string>* paths, const std::string& path) {
  if (path.empty()) {
    return;
  }
  for (const auto& existing : *paths) {
    if (existing == path) {
      return;
    }
  }
  paths->push_back(path);
}

std::string RunForOutput(const std::string& binary, const std::vector<std::string>& args) {
  int pipefd[2];
  if (pipe(pipefd) != 0) {
    return "";
  }

  pid_t pid = fork();
  if (pid == 0) {
    close(pipefd[0]);
    dup2(pipefd[1], STDOUT_FILENO);
    dup2(pipefd[1], STDERR_FILENO);
    close(pipefd[1]);

    std::vector<char*> argv;
    argv.push_back(const_cast<char*>(binary.c_str()));
    for (const auto& arg : args) {
      argv.push_back(const_cast<char*>(arg.c_str()));
    }
    argv.push_back(nullptr);
    execv(binary.c_str(), argv.data());
    _exit(127);
  }

  close(pipefd[1]);
  std::string output;
  char buffer[512];
  ssize_t bytes = 0;
  while ((bytes = read(pipefd[0], buffer, sizeof(buffer))) > 0) {
    output.append(buffer, static_cast<size_t>(bytes));
  }
  close(pipefd[0]);
  waitpid(pid, nullptr, 0);
  return output;
}

}  // namespace

std::string JoinPath(const std::string& base, const std::string& leaf) {
  if (base.empty()) {
    return leaf;
  }
  if (base.back() == '/') {
    return base + leaf;
  }
  return base + "/" + leaf;
}

DesktopCore& DesktopCore::Instance() {
  static DesktopCore instance;
  return instance;
}

std::string GetHomeDirectory() {
  const char* home = getenv("HOME");
  return home != nullptr ? std::string(home) : std::string();
}

std::string GetExecutableDirectory() {
  char path[4096];
  const ssize_t len = readlink("/proc/self/exe", path, sizeof(path) - 1);
  if (len <= 0) {
    return "";
  }
  path[len] = '\0';

  std::string full(path);
  const auto pos = full.find_last_of('/');
  if (pos == std::string::npos) {
    return "";
  }
  return full.substr(0, pos);
}

std::string GetWorkingDirectory() {
  const std::string home = GetHomeDirectory();
  if (home.empty()) {
    return "/tmp/v2ray_box";
  }
  return JoinPath(home, ".local/share/v2ray_box");
}

bool EnsureDirectory(const std::string& path) {
  if (path.empty()) {
    return false;
  }
  if (mkdir(path.c_str(), 0755) == 0 || errno == EEXIST) {
    return true;
  }

  std::stringstream ss(path);
  std::string part;
  std::string current;
  while (std::getline(ss, part, '/')) {
    if (part.empty()) {
      current = "/";
      continue;
    }
    current = current == "/" ? "/" + part : current + "/" + part;
    if (mkdir(current.c_str(), 0755) != 0 && errno != EEXIST) {
      return false;
    }
  }
  return true;
}

bool RemovePathIfExists(const std::string& path) {
  struct stat st {};
  if (stat(path.c_str(), &st) != 0) {
    return true;
  }
  if (S_ISDIR(st.st_mode)) {
    return rmdir(path.c_str()) == 0;
  }
  return unlink(path.c_str()) == 0;
}

bool WriteTextFile(const std::string& path, const std::string& content) {
  const auto slash = path.find_last_of('/');
  if (slash != std::string::npos) {
    const std::string parent = path.substr(0, slash);
    if (!EnsureDirectory(parent)) {
      return false;
    }
  }
  if (!RemovePathIfExists(path)) {
    return false;
  }

  std::ofstream out(path, std::ios::binary | std::ios::trunc);
  if (!out.is_open()) {
    return false;
  }
  out << content;
  out.flush();
  return out.good();
}

bool RemoveFileIfExists(const std::string& path) {
  if (!FileExists(path)) {
    return true;
  }
  return unlink(path.c_str()) == 0;
}

bool CopyFileIfMissing(const std::string& src, const std::string& dst) {
  if (!FileExists(src) || FileExists(dst)) {
    return FileExists(dst);
  }

  std::ifstream in(src, std::ios::binary);
  std::ofstream out(dst, std::ios::binary | std::ios::trunc);
  if (!in.is_open() || !out.is_open()) {
    return false;
  }
  out << in.rdbuf();
  return out.good();
}

void EnsureXrayGeoAssets(const std::string& work_dir,
                         const std::string& binary_path) {
  const std::string asset_dir = JoinPath(work_dir, "assets");
  EnsureDirectory(asset_dir);

  const auto slash = binary_path.find_last_of('/');
  const std::string binary_dir =
      slash == std::string::npos ? "" : binary_path.substr(0, slash);

  const char* geo_files[] = {"geoip.dat", "geosite.dat"};
  for (const char* geo_file : geo_files) {
    const std::string dst = JoinPath(asset_dir, geo_file);
    if (FileExists(dst)) {
      continue;
    }

    std::vector<std::string> candidates;
    AppendUnique(&candidates, JoinPath(binary_dir, geo_file));
    AppendUnique(&candidates,
                 JoinPath(binary_dir, std::string("resources/") + geo_file));

    const char* core_dir = getenv("V2RAY_BOX_CORE_DIR");
    if (core_dir != nullptr) {
      AppendUnique(&candidates, JoinPath(core_dir, geo_file));
    }

    for (const auto& candidate : candidates) {
      if (CopyFileIfMissing(candidate, dst)) {
        break;
      }
    }
  }
}

bool IsValidJson(const std::string& json) {
  if (json.empty()) {
    return false;
  }
  const char first = json.front();
  return first == '{' || first == '[';
}

std::string DesktopCore::FindBinary(const std::string& engine) const {
  const bool singbox = engine == "singbox";
  const char* binary_name = singbox ? kSingboxName : kXrayName;
  const char* env_override =
      singbox ? getenv("V2RAY_BOX_SINGBOX_PATH") : getenv("V2RAY_BOX_XRAY_PATH");

  std::vector<std::string> candidates;
  if (env_override != nullptr && env_override[0] != '\0') {
    AppendUnique(&candidates, env_override);
  }

  const char* core_dir = getenv("V2RAY_BOX_CORE_DIR");
  if (core_dir != nullptr) {
    AppendUnique(&candidates, JoinPath(core_dir, binary_name));
  }

  const std::string exe_dir = GetExecutableDirectory();
  AppendUnique(&candidates, JoinPath(exe_dir, binary_name));
  AppendUnique(&candidates, JoinPath(exe_dir, "lib/resources/" + std::string(binary_name)));
  AppendUnique(&candidates, JoinPath(exe_dir, "resources/" + std::string(binary_name)));
  AppendUnique(&candidates, JoinPath(exe_dir, "../resources/" + std::string(binary_name)));
  AppendUnique(&candidates, JoinPath(exe_dir, "../lib/resources/" + std::string(binary_name)));

  const std::string home = GetHomeDirectory();
  AppendUnique(&candidates,
               JoinPath(home, ".local/share/v2ray_box/cores/" + std::string(binary_name)));

  for (const auto& candidate : candidates) {
    if (IsExecutable(candidate)) {
      return candidate;
    }
    if (FileExists(candidate)) {
      chmod(candidate.c_str(), 0755);
      if (IsExecutable(candidate)) {
        return candidate;
      }
    }
  }
  return "";
}

std::string DesktopCore::GetVersion(const std::string& engine) const {
  const std::string binary = FindBinary(engine);
  if (binary.empty()) {
    return "";
  }
  return RunForOutput(binary, {"version"});
}

std::string ReadPipe(int fd) {
  std::string output;
  char buffer[512];
  ssize_t bytes = 0;
  while ((bytes = read(fd, buffer, sizeof(buffer))) > 0) {
    output.append(buffer, static_cast<size_t>(bytes));
  }
  return output;
}

std::string TrimOutput(const std::string& value) {
  const auto start = value.find_first_not_of(" \t\n\r");
  if (start == std::string::npos) {
    return "";
  }
  const auto end = value.find_last_not_of(" \t\n\r");
  return value.substr(start, end - start + 1);
}

std::string DesktopCore::Start(const std::string& engine,
                               const std::string& config_path,
                               const std::string& work_dir) {
  Stop();
  KillOrphanCoreProcesses(config_path);

  int socks_port = 1080;
  if (const char* port_env = getenv("SECURE_VPN_SOCKS_PORT")) {
    socks_port = std::atoi(port_env);
  }
  if (socks_port <= 0) {
    socks_port = 1080;
  }
  KillProcessOnPort(socks_port);
  KillProcessOnPort(socks_port + 1);

  const std::string binary = FindBinary(engine);
  if (binary.empty()) {
    return "Core binary not found. Run scripts/fetch_cores.sh and ensure "
           "linux/runner/resources contains xray/sing-box.";
  }

  int stderr_pipe[2];
  if (pipe(stderr_pipe) != 0) {
    return "Failed to create stderr pipe";
  }

  pid_t pid = fork();
  if (pid < 0) {
    close(stderr_pipe[0]);
    close(stderr_pipe[1]);
    return "Failed to fork core process";
  }

  if (pid == 0) {
    close(stderr_pipe[0]);
    dup2(stderr_pipe[1], STDERR_FILENO);
    close(stderr_pipe[1]);

    if (chdir(work_dir.c_str()) != 0) {
      _exit(126);
    }

    if (const char* user = getenv("SECURE_VPN_SOCKS_USER")) {
      setenv("SECURE_VPN_SOCKS_USER", user, 1);
    }
    if (const char* pass = getenv("SECURE_VPN_SOCKS_PASS")) {
      setenv("SECURE_VPN_SOCKS_PASS", pass, 1);
    }

    const std::string asset_dir = JoinPath(work_dir, "assets");
    EnsureDirectory(asset_dir);
    if (engine != "singbox") {
      EnsureXrayGeoAssets(work_dir, binary);
    }
    setenv("XRAY_LOCATION_ASSET", asset_dir.c_str(), 1);

    if (engine == "singbox") {
      const char* argv[] = {binary.c_str(), "run", "-c", config_path.c_str(), "-D",
                            work_dir.c_str(), nullptr};
      execv(binary.c_str(), const_cast<char* const*>(argv));
    } else {
      const char* argv[] = {binary.c_str(), "run", "-c", config_path.c_str(), nullptr};
      execv(binary.c_str(), const_cast<char* const*>(argv));
    }
    _exit(127);
  }

  close(stderr_pipe[1]);
  usleep(500000);
  int status = 0;
  const pid_t result = waitpid(pid, &status, WNOHANG);
  if (result == pid) {
    const std::string stderr_output = TrimOutput(ReadPipe(stderr_pipe[0]));
    close(stderr_pipe[0]);
    pid_ = -1;
    engine_.clear();
    if (!stderr_output.empty()) {
      return stderr_output;
    }
    return "Core process exited during startup";
  }

  close(stderr_pipe[0]);
  pid_ = pid;
  engine_ = engine;
  return "";
}

void DesktopCore::Stop() {
  if (pid_ <= 0) {
    return;
  }

  kill(pid_, SIGTERM);
  int status = 0;
  for (int i = 0; i < 20; ++i) {
    const pid_t result = waitpid(pid_, &status, WNOHANG);
    if (result == pid_) {
      pid_ = -1;
      engine_.clear();
      return;
    }
    usleep(100000);
  }

  kill(pid_, SIGKILL);
  waitpid(pid_, &status, 0);
  pid_ = -1;
  engine_.clear();
}

bool DesktopCore::IsRunning() const {
  if (pid_ <= 0) {
    return false;
  }
  int status = 0;
  const pid_t result = waitpid(pid_, &status, WNOHANG);
  if (result == pid_) {
    return false;
  }
  return kill(pid_, 0) == 0;
}

}  // namespace v2ray_box
