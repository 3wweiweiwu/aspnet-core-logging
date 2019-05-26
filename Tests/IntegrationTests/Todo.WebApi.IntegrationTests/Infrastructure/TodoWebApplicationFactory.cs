﻿using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Authorization;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using System;
using System.Collections.Generic;
using System.Linq;
using Todo.Persistence;
using Todo.Services;

namespace Todo.WebApi.Infrastructure
{
    // ReSharper disable once ClassNeverInstantiated.Global
    public class TodoWebApplicationFactory : WebApplicationFactory<Startup>
    {
        protected override TestServer CreateServer(IWebHostBuilder builder)
        {
            var testServer = base.CreateServer(builder);
            SeedDatabase(testServer.Host.Services);
            return testServer;
        }

        protected override void ConfigureWebHost(IWebHostBuilder builder)
        {
            builder.ConfigureTestServices(services =>
            {
                services.AddMvc(options =>
                {
                    options.Filters.Add(new AllowAnonymousFilter());
                    options.Filters.Add(new InjectTestUserFilter());
                });
            });
        }

        private void SeedDatabase(IServiceProvider serviceProvider)
        {
            using (var serviceScope = serviceProvider.CreateScope())
            {
                var todoDbContext = serviceScope.ServiceProvider.GetRequiredService<TodoDbContext>();
                var databaseSeeder = serviceScope.ServiceProvider.GetRequiredService<IDatabaseSeeder>();
                databaseSeeder.Seed(todoDbContext,GetItems(0));
            }
        }

        private IList<TodoItem> GetItems(int count)
        {
            if (count <= 0)
            {
                return Enumerable.Empty<TodoItem>().ToList();
            }

            var result = Enumerable.Range(1, count)
                                   .Select(index => new TodoItem
                                   {
                                       IsComplete = true
                                     , Name = $"TodoItem #{index}"
                                     , CreatedBy = TestUserSettings.UserId
                                     , CreatedOn = DateTime.Now
                                   })
                                   .ToList();

            return result;
        }
    }
}