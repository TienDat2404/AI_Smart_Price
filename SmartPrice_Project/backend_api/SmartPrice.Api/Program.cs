using SmartPrice.Api.Models; 
using MongoDB.Driver;
var builder = WebApplication.CreateBuilder(args);

// 1. Ánh xạ cấu hình (Mapping)
builder.Services.Configure<SmartPriceDatabaseSettings>(
    builder.Configuration.GetSection("SmartPriceDatabase"));

// 2. Khởi tạo MongoClient từ chuỗi kết nối trong file JSON
builder.Services.AddSingleton<IMongoClient>(sp => {
    var settings = builder.Configuration.GetSection("SmartPriceDatabase").Get<SmartPriceDatabaseSettings>();
    return new MongoClient(settings?.ConnectionString);
});
// Add services to the container.
// Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();

var summaries = new[]
{
    "Freezing", "Bracing", "Chilly", "Cool", "Mild", "Warm", "Balmy", "Hot", "Sweltering", "Scorching"
};

app.MapGet("/weatherforecast", () =>
{
    var forecast =  Enumerable.Range(1, 5).Select(index =>
        new WeatherForecast
        (
            DateOnly.FromDateTime(DateTime.Now.AddDays(index)),
            Random.Shared.Next(-20, 55),
            summaries[Random.Shared.Next(summaries.Length)]
        ))
        .ToArray();
    return forecast;
})
.WithName("GetWeatherForecast")
.WithOpenApi();

// Đoạn code chạy thử để kiểm tra kết nối (Dán trước app.Run();)
using (var scope = app.Services.CreateScope())
{
    var client = scope.ServiceProvider.GetRequiredService<IMongoClient>();
    var db = client.GetDatabase("SmartPriceDB");
    var collection = db.GetCollection<Transaction>("Transactions");

    if (collection.CountDocuments(new FilterDefinitionBuilder<Transaction>().Empty) == 0)
    {
        collection.InsertOne(new Transaction { 
            ItemName = "Giao dịch đầu tiên", 
            Amount = 50000, 
            Date = DateTime.Now, 
            Category = "Ăn uống" 
        });
        Console.WriteLine(">>> KẾT NỐI MONGODB THÀNH CÔNG! Đã tạo dữ liệu mẫu.");
    }
}

app.Run();

record WeatherForecast(DateOnly Date, int TemperatureC, string? Summary)
{
    public int TemperatureF => 32 + (int)(TemperatureC / 0.5556);
}
