Gem::Specification.new do |s|
  s.name         = "harbor_utils"
  s.version      = "1.0.1"
  s.author       = "Martin Mareš"
  s.email        = "martin.mares@seznam.cz"
  s.summary      = "Harbor utility (docker registry). Working with Harbor REST API spec."
  s.homepage     = "https://cloud-app.cz"
  s.licenses     = ['MIT']
  # s.description  = File.read(File.join(File.dirname(__FILE__), 'README'))

  s.files         = Dir["{bin,lib,spec}/**/*"] + %w(LICENSE README.md)
  s.test_files    = Dir["spec/**/*"]
  s.executables   = [ 'harbor_utils' ]

  s.required_ruby_version = '>=3'
  # s.add_development_dependency 'rspec', '~> 2.8', '>= 2.8.0'
end
