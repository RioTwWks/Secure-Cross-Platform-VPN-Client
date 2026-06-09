#ifndef V2RAY_BOX_DESKTOP_CORE_H_
#define V2RAY_BOX_DESKTOP_CORE_H_

#include <string>

namespace v2ray_box {

class DesktopCore {
 public:
  static DesktopCore& Instance();

  std::string Start(const std::string& engine,
                    const std::string& config_path,
                    const std::string& work_dir);
  void Stop();
  bool IsRunning() const;
  std::string FindBinary(const std::string& engine) const;
  std::string GetVersion(const std::string& engine) const;

 private:
  DesktopCore() = default;
  pid_t pid_ = -1;
  std::string engine_;
};

std::string GetHomeDirectory();
std::string GetExecutableDirectory();
std::string GetWorkingDirectory();
std::string JoinPath(const std::string& base, const std::string& leaf);
bool EnsureDirectory(const std::string& path);
bool RemovePathIfExists(const std::string& path);
bool WriteTextFile(const std::string& path, const std::string& content);
bool RemoveFileIfExists(const std::string& path);
bool CopyFileIfMissing(const std::string& src, const std::string& dst);
void EnsureXrayGeoAssets(const std::string& work_dir,
                         const std::string& binary_path);
bool IsValidJson(const std::string& json);

}  // namespace v2ray_box

#endif  // V2RAY_BOX_DESKTOP_CORE_H_
