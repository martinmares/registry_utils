Gem::Specification.new do |s|
  s.name         = "registry_utils"
  s.version      = "1.2.2"
  s.author       = "Martin Mareš"
  s.email        = "martin.mares@seznam.cz"
  s.summary      = "Registry utility (Docker + Harbor). Working with Harbor REST API spec."
  s.homepage     = "https://cloud-app.cz"
  s.licenses     = ['MIT']
  # s.description  = File.read(File.join(File.dirname(__FILE__), 'README'))

  s.files         = Dir["{bin,lib,spec}/**/*"] + %w(LICENSE README.md)
  s.test_files    = Dir["spec/**/*"]
  s.executables   = ['docker_reg_utils']

  s.required_ruby_version = '>=3'
end
