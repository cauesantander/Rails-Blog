# Development data. Idempotent: safe to run `bin/rails db:seed` many times.
# Credentials for the seeded accounts come from the environment (defaults are for local use only).
# Test databases must stay isolated; RSpec creates its own records through factories.
if Rails.env.test?
  puts "Skipping seeds in test: RSpec manages its own data."
  return
end

# `db:prepare` also seeds a brand-new database (e.g. first production boot): skip instead
# of failing the boot, and never create an admin with the default password in production.
if Rails.env.production? && ENV["ADMIN_PASSWORD"].blank?
  puts "Skipping seeds in production: set ADMIN_EMAIL/ADMIN_PASSWORD to create the first admin."
  return
end

admin = User.find_or_initialize_by(email_address: ENV.fetch("ADMIN_EMAIL", "admin@example.com"))
admin.update!(name: "Admin", role: :admin, password: ENV.fetch("ADMIN_PASSWORD", "password123")) if admin.new_record?

reader = User.find_or_initialize_by(email_address: "leitor@example.com")
reader.update!(name: "Leitora Exemplo", password: "password123") if reader.new_record?

categories = %w[Ruby Rails Arquitetura].map { Category.find_or_create_by!(name: it) }

posts = [
  { title: "Primeiros passos com Ruby on Rails", category: categories[1], tags: "rails, iniciante",
    body: "Rails segue **convenção sobre configuração**.\n\n```ruby\nclass Post < ApplicationRecord\n  belongs_to :author\nend\n```" },
  { title: "Sidekiq e Redis na prática", category: categories[2], tags: "sidekiq, redis, jobs",
    body: "Jobs assíncronos tiram trabalho lento do ciclo de request.\n\n- Retries com backoff exponencial\n- Idempotência\n- Filas com peso" },
  { title: "Blocos, procs e lambdas", category: categories[0], tags: "ruby",
    body: "Em Ruby, blocos são a base de iteradores como `each` e `map`." }
]
posts.each_with_index do |attrs, index|
  post = Post.find_or_initialize_by(title: attrs[:title])
  next unless post.new_record?

  post.update!(author: admin, category: attrs[:category], body: attrs[:body], tag_list: attrs[:tags],
               excerpt: attrs[:body].lines.first.strip, status: :published, published_at: (index + 1).days.ago)
  post.comments.create!(user: reader, body: "Ótimo artigo, obrigado!")
end

Post.find_or_create_by!(title: "Rascunho: Hotwire e Turbo") do |post|
  post.author = admin
  post.body = "Ainda escrevendo..."
end

5.times do |i|
  Subscriber.find_or_create_by!(email: "inscrito#{i + 1}@example.com") do |subscriber|
    subscriber.status = :confirmed
    subscriber.confirmed_at = Time.current
  end
end

puts "Seeds OK: #{User.count} users, #{Post.count} posts, #{Subscriber.confirmed.count} confirmed subscribers"
puts "Admin login: #{admin.email_address} / #{ENV.fetch('ADMIN_PASSWORD', 'password123')}" unless Rails.env.production?
