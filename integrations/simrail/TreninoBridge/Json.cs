using System.Text.Json;
using System.Text.Json.Serialization;

namespace TreninoBridge;

internal static class Json
{
    public static readonly JsonSerializerOptions Options = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
        NumberHandling = JsonNumberHandling.AllowNamedFloatingPointLiterals,
        Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping,
    };

    public static string Serialize(object? value) => JsonSerializer.Serialize(value, Options);

    public static byte[] SerializeBytes(object? value) => JsonSerializer.SerializeToUtf8Bytes(value, Options);
}
