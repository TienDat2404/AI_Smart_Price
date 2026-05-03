using Microsoft.Extensions.Options;
using MongoDB.Driver;
using SmartPrice.Api.Models;
using SmartPrice.Api.Services;

var builder = WebApplication.CreateBuilder(args);

// ── 1. Cấu hình Database ──────────────────────────────────────────────────────
builder.Services.Configure<SmartPriceDatabaseSettings>(
    builder.Configuration.GetSection("SmartPriceDatabase"));

// ── 2. Đăng ký MongoClient (Singleton) ───────────────────────────────────────
builder.Services.AddSingleton<IMongoClient>(sp =>
{
    var settings = sp.GetRequiredService<IOptions<SmartPriceDatabaseSettings>>().Value;
    return new MongoClient(settings.ConnectionString);
});

// ── 3. Đăng ký IMongoDatabase (Singleton) ────────────────────────────────────
builder.Services.AddSingleton<IMongoDatabase>(sp =>
{
    var settings = sp.GetRequiredService<IOptions<SmartPriceDatabaseSettings>>().Value;
    var client   = sp.GetRequiredService<IMongoClient>();
    return client.GetDatabase(settings.DatabaseName);
});

// ── 4. Đăng ký DataSeeder ─────────────────────────────────────────────────────
builder.Services.AddScoped<DataSeeder>();
builder.Services.AddScoped<UserService>();

// ── 4b. HttpClient cho AI Engine ─────────────────────────────────────────────
builder.Services.AddHttpClient("AiEngine", client =>
{
    client.BaseAddress = new Uri("http://localhost:8000");
    client.Timeout     = TimeSpan.FromSeconds(25); // AI Engine timeout
});

// ── 5. CORS — cho phép Flutter Web và Mobile gọi API ─────────────────────────
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader());
});

// ── 6. Controllers & Swagger ──────────────────────────────────────────────────
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new() { Title = "SmartPrice API", Version = "v1" });
});

var app = builder.Build();

// ── 7. Chạy DataSeeder khi khởi động ─────────────────────────────────────────
using (var scope = app.Services.CreateScope())
{
    var seeder = scope.ServiceProvider.GetRequiredService<DataSeeder>();
    await seeder.SeedAsync();
}

// ── 8. Middleware pipeline ────────────────────────────────────────────────────
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI(c => c.SwaggerEndpoint("/swagger/v1/swagger.json", "SmartPrice API v1"));
}
else
{
    // Chỉ redirect HTTPS ở production — dev dùng HTTP để Flutter kết nối dễ hơn
    app.UseHttpsRedirection();
}

// CORS phải đứng trước Authorization và MapControllers
app.UseCors("AllowAll");
app.UseAuthorization();
app.MapControllers();

app.Run();
