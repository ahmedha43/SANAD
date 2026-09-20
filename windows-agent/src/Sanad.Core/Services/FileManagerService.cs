using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;

using System.Text.Json.Serialization;

namespace Sanad.Core.Services
{
    public class FileManagerService
    {
        public class FileItem
        {
            [JsonPropertyName("name")]
            public string Name { get; set; } = string.Empty;

            [JsonPropertyName("path")]
            public string Path { get; set; } = string.Empty;

            [JsonPropertyName("file_path")]
            public string FilePath => Path;

            [JsonPropertyName("is_directory")]
            public bool IsDirectory { get; set; }

            [JsonPropertyName("size")]
            public long Size { get; set; }

            [JsonPropertyName("modified_at")]
            public long ModifiedAt { get; set; }
        }

        public class FileDataResponse
        {
            [JsonPropertyName("current_path")]
            public string CurrentPath { get; set; } = string.Empty;

            [JsonPropertyName("file_path")]
            public string FilePath { get; set; } = string.Empty;

            [JsonPropertyName("items")]
            public List<FileItem> Items { get; set; } = new();

            [JsonPropertyName("file_base64")]
            public string? FileBase64 { get; set; }

            [JsonPropertyName("fileBase64")]
            public string? FileBase64Camel => FileBase64;

            [JsonPropertyName("error")]
            public string? Error { get; set; }
        }

        public FileDataResponse HandleFetchRequest(string? requestedPath)
        {
            var response = new FileDataResponse();

            try
            {
                // If path is empty, return common user libraries
                if (string.IsNullOrWhiteSpace(requestedPath) || requestedPath == "ROOT")
                {
                    response.CurrentPath = "ROOT";
                    var userProfile = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);

                    var libraries = new (string name, Environment.SpecialFolder folder)[]
                    {
                        ("الصور (Pictures)", Environment.SpecialFolder.MyPictures),
                        ("التنزيلات (Downloads)", Environment.SpecialFolder.UserProfile), // will append Downloads
                        ("المستندات (Documents)", Environment.SpecialFolder.MyDocuments),
                        ("سطح المكتب (Desktop)", Environment.SpecialFolder.Desktop)
                    };

                    foreach (var (name, folder) in libraries)
                    {
                        var path = folder == Environment.SpecialFolder.UserProfile && name.Contains("Downloads")
                            ? Path.Combine(userProfile, "Downloads")
                            : Environment.GetFolderPath(folder);

                        if (Directory.Exists(path))
                        {
                            response.Items.Add(new FileItem
                            {
                                Name = name,
                                Path = path,
                                IsDirectory = true,
                                Size = 0,
                                ModifiedAt = DateTimeOffset.UtcNow.ToUnixTimeSeconds()
                            });
                        }
                    }
                    return response;
                }

                // If path is a specific file, return base64
                if (File.Exists(requestedPath))
                {
                    var fileInfo = new FileInfo(requestedPath);
                    response.CurrentPath = requestedPath;
                    response.FilePath = requestedPath;

                    // Limit file read size to 10MB
                    if (fileInfo.Length <= 10 * 1024 * 1024)
                    {
                        var bytes = File.ReadAllBytes(requestedPath);
                        response.FileBase64 = Convert.ToBase64String(bytes);
                    }
                    else
                    {
                        response.Error = "حجم الملف كبير جداً للعرض المباشر (أكبر من 10 ميجابايت)";
                    }
                    return response;
                }

                // If path is a directory, list items
                if (Directory.Exists(requestedPath))
                {
                    response.CurrentPath = requestedPath;
                    var dirInfo = new DirectoryInfo(requestedPath);

                    // Subdirectories
                    foreach (var d in dirInfo.GetDirectories().Take(50))
                    {
                        if ((d.Attributes & FileAttributes.Hidden) != 0) continue;
                        response.Items.Add(new FileItem
                        {
                            Name = d.Name,
                            Path = d.FullName,
                            IsDirectory = true,
                            Size = 0,
                            ModifiedAt = new DateTimeOffset(d.LastWriteTimeUtc).ToUnixTimeSeconds()
                        });
                    }

                    // Files
                    foreach (var f in dirInfo.GetFiles().Take(100))
                    {
                        if ((f.Attributes & FileAttributes.Hidden) != 0) continue;
                        response.Items.Add(new FileItem
                        {
                            Name = f.Name,
                            Path = f.FullName,
                            IsDirectory = false,
                            Size = f.Length,
                            ModifiedAt = new DateTimeOffset(f.LastWriteTimeUtc).ToUnixTimeSeconds()
                        });
                    }

                    return response;
                }

                response.Error = "المسار المطلوب غير موجود";
            }
            catch (Exception ex)
            {
                response.Error = $"خطأ أثناء قراءة الملفات: {ex.Message}";
            }

            return response;
        }
    }
}
