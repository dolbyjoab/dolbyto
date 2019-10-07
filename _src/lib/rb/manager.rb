#encoding: utf-8

# File: manager.rb
# Language: Ruby
# Country/State: Brazil/SP
# Author : William C. Canin <http://williamcanin.me>
# Description: Script for project management.

require "colorize"
require "open3"
require "json"
require "date"

class Manager

    SOURCE = "."
    CONFIG = {
      'ROOT_VENDOR' => File.join(SOURCE, "assets/vendor"),
      'VENDORJS_DIR' => File.join(SOURCE, "assets/vendor/js"),
      'NODE_MODULES' => File.join(SOURCE, "vendor/node_modules"),
      'POST_DIR' => File.join(SOURCE, "_posts"),
      'PAGE_DIR' => File.join(SOURCE, "_pages"),
      'PUBLIC_DIR' => File.join(SOURCE, "public"),
      'DEPLOY_JSON' => File.join(SOURCE, "_src/lib/json/deploy.json"),
      'markdown_extension' => "md"
    }

    def create_directory(path)
      unless File.directory?(path)
        puts "> Create folder '#{path}'...".blue
        FileUtils.mkdir_p(path)
        puts "> Folder '#{path}', created!".green
      end
    end # create_directory

    def copy_file(origin, destiny)
      FileUtils.cp(origin, destiny)
    end # copy_file

    def postinstall
      create_directory(CONFIG['VENDORJS_DIR'])
      files = ['jquery/dist/jquery.min.js',
                'popper.js/dist/umd/popper.min.js',
                'bootstrap/dist/js/bootstrap.min.js',
                'simple-jekyll-search/dest/simple-jekyll-search.min.js'
              ]
      for f in files
        # unless File.exist?(f)
          copy_file("#{CONFIG['NODE_MODULES']}/#{f}", CONFIG['VENDORJS_DIR'])
          puts "> File '#{f}' copied to #{CONFIG['VENDORJS_DIR']}!".green
        # end
      end
    end # postinstall
    
    def slug_generator(parameter)
      parameter.downcase.strip.gsub(' ', '-').gsub(/[^\w-]/, '')
    end # slug_generator

    def datetime_generator(parameter)
      begin
        datetime_get = (ENV['date'] ? Time.parse(ENV['date']) : Time.now).strftime(parameter)
      rescue => e
        puts "Error - date format must be YYYY-MM-DD, please check you typed it correctly!"
        exit -1
      end
    end # datetime_generator

    def enginer(directory, message, type)
      abort("Rake aborted: #{directory} directory not found.") unless FileTest.directory?(directory)
      begin
        print "#{message}\n> ".blue
        title = STDIN.gets.chomp
      rescue Interrupt => e
        puts "\nApproached by the user".yellow
        exit -1
      end
      slug = slug_generator(title)
      date = datetime_generator('%Y-%m-%d')
      datetime = datetime_generator('%Y-%m-%d %R:%S')
      if type == 'page'
        filename = File.join(directory, "#{slug}.#{CONFIG['markdown_extension']}")
      else
        filename = File.join(directory, "#{date}-#{slug}.#{CONFIG['markdown_extension']}")
      end
      if File.exist?(filename)
        abort("Action aborted by user!") if ask("#{filename} already exists. Do you want to overwrite?", ['y', 'n']) == 'n'
      end
      return title, date, datetime, filename
    end # enginer


    def page_create
      array = enginer(CONFIG['PAGE_DIR'], 'Enter the name for the new page:', 'page')
      puts "Creating new page: #{array[3]}".green
      open(array[3], 'w') do |file|
        file.puts("---")
        file.puts("layout: page")
        file.puts("order: #number")
        file.puts("title: \"#{array[0]}\"")
        file.puts("date: #{array[2]}")
        file.puts("sitemap:")
        file.puts("  priority: 0.7")
        file.puts("  changefreq: 'monthly'")
        file.puts("  lastmod: #{array[2]}")
        file.puts("# Use icons of: https://fontawesome.com/icons")
        file.puts("# E.g: fa-briefcase")
        file.puts("icon: ")
        file.puts("menu:")
        file.puts("  enable: true")
        file.puts("  local: [default]")
        file.puts("script: []")
        file.puts("published: false")
        file.puts("permalink: # add permilink for page. E.g: /smallparty/")
        file.puts("---")
        file.puts("")
        file.puts "<!-- Write from here your page !!! -->"
        puts "Created successfully!"
      end #open
    end # page_create

    def post_create
      array = enginer(CONFIG['POST_DIR'], 'Enter new post title:', 'post')
      puts "Creating new post: #{array[3]}"
      open(array[3], 'w') do |file|
        file.puts("---")
        file.puts("layout: post")
        file.puts("title: \"#{array[0]}\"")
        file.puts("date: #{array[2]}")
        file.puts("tags: ['tag1','tag2','tag3']")
        file.puts("published: false")
        file.puts("comments: false")
        file.puts("excerpted: |
        Put here your excerpt")
        file.puts("day_quote:")
        file.puts(" title: \"Put here title quote of the day\"")
        file.puts(" description: |
        \"Put here your quote of the day\"")
        file.puts("")
        file.puts("# Does not change and does not remove 'script' variable.")
        file.puts("script: [post.js]")
        file.puts("---")
        file.puts("")
        file.puts "<!-- Write from here your post !!! -->"
        puts "Created successfully!"
      end # open
    end # post_create

    def deploy_public
      datetime = DateTime.now
      deploy_json = open(CONFIG['DEPLOY_JSON'])
      parsed = JSON.parse(deploy_json.read)

      begin
        if parsed['public']['git']['init'] == false
          create_git_init = """
          cd #{CONFIG['PUBLIC_DIR']}
          git init
          """
          Open3.popen3(create_git_init)
          parsed['public']['git']['init'] = true
          File.write(CONFIG['DEPLOY_JSON'], JSON.pretty_generate(parsed))
        end

        if parsed['public']['git']['origin'] == "" and 
          parsed['public']['git']['remote'] == ""
          print "Enter the origin:\n> ".blue
          origin = STDIN.gets.chomp

          print "Enter the remote address:\n> ".blue
          remote = STDIN.gets.chomp
          
          add_remote = """
            cd #{CONFIG['PUBLIC_DIR']}
            git remote add #{origin} #{remote}
          """

          Open3.popen3(add_remote)
          
          parsed['public']['git']['origin'] = origin
          parsed['public']['git']['remote'] = remote
          File.write(CONFIG['DEPLOY_JSON'], JSON.pretty_generate(parsed))

        end

        commit = """
          cd #{CONFIG['PUBLIC_DIR']}
          git add .
          git commit -m \"Update - #{datetime}\"
        """
        Open3.popen3(commit)

        if parsed['public']['git']['branch'] == ""
          print "Add branch:\n> ".blue
          branch = STDIN.gets.chomp
            
          add_branch = """
            cd #{CONFIG['PUBLIC_DIR']}
            git checkout -b #{branch}
          """
          Open3.popen3(add_branch)
          parsed['public']['git']['branch'] = branch
          File.write(CONFIG['DEPLOY_JSON'], JSON.pretty_generate(parsed))
        end

        push = """
        cd #{CONFIG['PUBLIC_DIR']}
        git push #{parsed['public']['git']['origin']} #{parsed['public']['git']['branch']}
        """
        Open3.popen3(push) do |stdout, stderr|
          puts stdout
          puts stderr
        end
      
      rescue Interrupt => e
        puts "\nApproached by the user".yellow
        exit -1
      end # begin

    end # deploy_public
end # Main