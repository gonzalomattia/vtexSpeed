proxy = require('proxy-middleware')
serveStatic = require('serve-static')
httpPlease = require('connect-http-please')
url = require('url')
middlewares = require('./speed-middleware')

module.exports = (grunt) ->
  pkg = grunt.file.readJSON('package.json')

  accountName = process.env.VTEX_ACCOUNT or pkg.accountName or 'basedevmkp'

  environment = process.env.VTEX_ENV or 'vtexcommercestable'

  secureUrl = process.env.VTEX_SECURE_URL or pkg.secureUrl

  verbose = grunt.option('verbose')

  if secureUrl
    imgProxyOptions = url.parse("https://#{accountName}.vtexassets.com/files")
  else
    imgProxyOptions = url.parse("http://#{accountName}.vtexassets.com/files")

  imgProxyOptions.route = '/files'

  # portalHost is also used by connect-http-please
  # example: basedevmkp.vtexcommercestable.com.br
  portalHost = "#{accountName}.#{environment}.com.br"
  if secureUrl
    portalProxyOptions = url.parse("https://#{portalHost}/")
  else
    portalProxyOptions = url.parse("http://#{portalHost}/")
  portalProxyOptions.preserveHost = true
  portalProxyOptions.cookieRewrite = accountName + ".vtexlocal.com.br";
  
  rewriteLocation = (location) ->
    return location
      .replace('https:', 'http:')
      .replace(environment, 'vtexlocal')

  config =
    pkg:
      grunt.file.readJSON('package.json')

    clean:
      main: ['build']

    copy:
      main:
        files: [
          expand: true
          cwd: 'src/'
          src: ['**', '!**/*.coffee', '!**/inc-*.less', '!**/inc-*.js']
          dest: "build/"
        ]

    coffee:
      main:
        files: [
          expand: true
          cwd: 'src'
          src: ['**/*.coffee']
          dest: "build/files/"
          ext: '.js'
        ]

    less:
      main:
        files: [
          expand: true
          cwd: 'src/styles/'
          src: ['**/*.less', '!**/inc-*.less']
          dest: "build/files/"
          ext: '.css'
        ]

    cssmin:
      main:
        expand: true
        cwd: 'build/files/'
        src: ['*.css', '!*.min.css']
        dest: 'build/files/'
        ext: '.css'

    uglify:
      options:
        mangle: false
      main:
        files: [{
          expand: true
          cwd: 'build/files/'
          src: ['*.js', '!*.min.js']
          dest: 'build/files/'
          ext: '.js'
        }]

    concat:
      options:
        separator: '\n'
        stripBanners: true
        banner: '/*! <%= pkg.BannerName %> - v<%= pkg.version %> - ' + '<%= grunt.template.today("yyyy-mm-dd") %> - UX: <%= pkg.Developer %> */' + '\n'
      dist:
        src: ['src/scripts/inc-*.js'],
        dest: 'build/files/<%= pkg.fileName %>.js',

    imagemin:
      main:
        files: [
          expand: true
          cwd: 'build/files/'
          src: ['**/*.{png,jpg,gif}']
          dest: 'build/files/'
        ]

    connect:
      http:
        options:
          hostname: "*"
          livereload: true
          port: process.env.PORT || 80
          middleware: [
            middlewares.disableCompression
            middlewares.rewriteLocationHeader(rewriteLocation)
            middlewares.replaceHost(portalHost)
            middlewares.replaceHtmlBody(environment, accountName, secureUrl)
            httpPlease(host: portalHost, verbose: verbose)
            serveStatic('./build')
            proxy(imgProxyOptions)
            proxy(portalProxyOptions)
            middlewares.errorHandler
          ]

    watch:
      options:
        livereload: true
      coffee:
        files: ['src/**/*.coffee']
        tasks: ['coffee']
      less:
        options:
          livereload: false
        files: ['src/**/*.less']
        tasks: ['less']
      images:
        files: ['src/**/*.{png,jpg,gif}']
        tasks: ['imagemin']
      css:
        files: ['build/**/*.css']
      main:
        files: ['src/**/*.html', 'src/**/*.js', 'src/**/*.css']
        tasks: ['copy','concat']
      grunt:
        files: ['Gruntfile.coffee']

  tasks =
    # Building block tasks
    default: ['clean', 'copy:main', 'coffee', 'less', 'imagemin', 'concat', 'uglify', 'cssmin', 'connect', 'watch']

  # Project configuration.
  grunt.config.init config
  if grunt.cli.tasks[0] is 'less'
    grunt.loadNpmTasks 'grunt-contrib-less'
  else if grunt.cli.tasks[0] is 'coffee'
    grunt.loadNpmTasks 'grunt-contrib-coffee'
  else
    grunt.loadNpmTasks name for name of pkg.devDependencies when name[0..5] is 'grunt-'
  grunt.registerTask taskName, taskArray for taskName, taskArray of tasks