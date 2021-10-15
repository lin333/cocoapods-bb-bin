require 'fileutils'

module Pod
  class Command
    class Bin < Command
      class Code < Bin
        self.summary = '通过将二进制对应源码放置在临时目录中，让二进制出现断点时可以跳到对应的源码，方便调试。'

        self.description = <<-DESC
          通过将二进制对应源码放置在临时目录中，让二进制出现断点时可以跳到对应的源码，方便调试。
          在不删除二进制的情况下为某个组件添加源码调试能力，多个组件名称用空格分隔
        DESC

        self.arguments = [
            CLAide::Argument.new('NAME', false)
        ]
        def self.options
          [
              ['--all-clean', '删除所有已经下载的源码'],
              ['--clean', '删除所有指定下载的源码'],
              ['--list', '展示所有一级下载的源码以及其大小'],
              ['--source', '源码路径，本地路径,会去自动链接本地源码'],
              ['--simulator', '是否模拟器架构，xcframework需要'],# 是否模拟器，默认NO，xcframework需要使用
          ]
        end

        def initialize(argv)
          @codeSource =  argv.option('source') || nil
          @names = argv.arguments! unless argv.arguments.empty?
          @list = argv.flag?('list', false )
          @all_clean = argv.flag?('all-clean', false )
          @clean = argv.flag?('clean', false )
          @simulator = argv.flag?('simulator', false )

          @config = Pod::Config.instance

          super
        end


        def run

          podfile_lock = File.join(Pathname.pwd,"Podfile.lock")
          raise "podfile.lock,不存在，请先pod install/update" unless File.exist?(podfile_lock)
          @lockfile ||= Lockfile.from_file(Pathname.new(podfile_lock) )

          if @list
            list
          elsif @clean
            clean
          elsif @all_clean
            all_clean
          elsif @names
            add
          end

          if @list && @clean && @names
            raise "请选择您要执行的命令。"
          end
        end

        #==========================begin add ==============

        def add
          if @names == nil
            raise "请输入要调试组件名，多个组件名称用空格分隔"
          end

          @names.each do  |name|
            lib_file = get_lib_path(name)
            unless File.exist?(lib_file)
              raise "找不到 #{lib_file}"
            end
            UI.puts "#{lib_file}"

            target_path =  @codeSource || download_source(name)
            puts "====add lib_file: #{lib_file} target_path: #{target_path} name: #{name}"
            link(lib_file,target_path,name)
          end
        end

        #下载源码到本地
        def download_source(name)
          target_path =  File.join(source_root, name)
          UI.puts target_path
          FileUtils.rm_rf(target_path)

          find_dependency = find_dependency(name)

          spec = fetch_external_source(find_dependency, @config.podfile,@config.lockfile, @config.sandbox,true )

          download_request = Pod::Downloader::Request.new(:name => name, :spec => spec)
          Downloader.download(download_request, Pathname.new(target_path), :can_cache => true)

          target_path
        end

        #找出依赖
        def find_dependency (name)
          find_dependency = nil
          @config.podfile.dependencies.each do |dependency|
            if dependency.root_name.downcase == name.downcase
              find_dependency = dependency
              break
            end
          end
          find_dependency
        end

        # 获取external_source 下的仓库
        # @return spec
        def fetch_external_source(dependency ,podfile , lockfile, sandbox,use_lockfile_options)
          source = ExternalSources.from_dependency(dependency, podfile.defined_in_file, true)
          source.fetch(sandbox)
        end


        #==========================link begin ==============

        #链接，.a文件位置， 源码目录，工程名=IMYFoundation
        def link(lib_file,target_path,basename)
          print <<EOF
          link 源码
          `dwarfdump "#{lib_file}" | grep "AT_comp_dir" | head -1 | cut -d \\" -f2 `
EOF
          dir = (`dwarfdump "#{lib_file}" | grep "AT_comp_dir" | head -1 | cut -d \\" -f2 `)
          UI.puts "dwarfdump dir = #{dir}"
          # if Pathname.new(lib_file).extname == ".a"
          #   sub_path = "#{basename}/bin-archive/#{basename}"
          # else
          #   sub_path = "#{basename}"
          # end
          sub_path = "#{basename}/bin-archive/#{basename}"
          dir = dir.gsub(sub_path, "").chomp
          UI.puts "Binary dir = #{dir}"

          unless File.exist?(dir)
            # UI.puts "不存在 = #{dir}"
            begin
              FileUtils.mkdir_p(dir) unless File.exists?(dir) # require 'fileutils'
            rescue SystemCallError
              # mkdir: _fzzfm3x4y17bm6psx9yhbs00000gn: Permission denied
              unless File.exist?(dir)
                user_name_array = Dir.home.split('/') # Dir.home = /Users/xx,xx表示当前用户名称
                user_name = "501"
                user_name_array.each do |name|
                  user_name = name
                end
                UI.puts "user_name = #{user_name}".yellow
                `sudo mkdir -p #{dir} && sudo chown -R #{user_name}:wheel #{dir}`
              end
              #判断用户目录是否存在
              array = dir.split('/')
              if array.length > 5
                root_path = '/' + array[1] + '/' + array[2] + '/' + array[3] + '/' + array[4]
                UI.puts "root_path = #{root_path}"
                unless File.exist?(root_path)
                  raise "由于权限不足，请手动创建#{root_path} 后重试"
                end
              end
            end
          end
          unless File.exist?(dir) 
            raise Informative, "【切换源码】由于权限不足，请手动创建目录: #{dir} 授权mobile权限后重试"
          end

          if Pathname.new(lib_file).extname == ".a"
            FileUtils.rm_rf(File.join(dir,basename))
            `ln -s #{target_path} #{dir}`
          else
            FileUtils.rm_rf(File.join(dir,basename))
            `ln -s #{target_path} #{dir}/#{basename}`
          end

          check(lib_file,dir,basename)
        end

        def check(lib_file,dir,basename)
          print <<EOF
          check 源码
          `dwarfdump "#{lib_file}" | grep -E "DW_AT_decl_file.*#{basename}.*\\.m|\\.c" | head -1 | cut -d \\" -f2`
EOF
          file = `dwarfdump "#{lib_file}" | grep -E "DW_AT_decl_file.*#{basename}.*\\.m|\\.c" | head -1 | cut -d \\" -f2`
          if File.exist?(file)
            raise Informative, "#{file} 不存在 请检测代码源是否正确~"
          end
          UI.puts "library file: #{lib_file} dwarfdump file: #{file}"
          UI.puts "link successfully!".yellow
          UI.puts "view linked source at path: #{dir}".yellow
        end

        def get_lib_path(name)
          dir = Pathname.new(File.join(Pathname.pwd,"Pods",name))
          # 遍历组件目录判断
          Dir.foreach(dir) do |filename|
            if filename != "." and filename != ".."
              filepath = File.join(dir,"#{filename}")
              if File.file?(filepath)
                if File.extname(filepath) == '.a' # .a库
                  return filepath
                end
              else
                if File.extname(filepath) == '.framework' # .framework库
                  return File.join(filepath,name)
                end
                if File.extname(filepath) == '.xcframework' # .xcframework库
                  
                  print <<EOF
          获取xcframework架构 ls -al "#{filepath}"
EOF
                  # 构建xcframework架构需要根据实际二进制文件进行条件判断
                  arm_name = ""
                  if @simulator
                    arm_name = "ios-arm64_i386_x86_64-simulator"
                  else
                    arm_name = "ios-arm64_armv7"
                  end
                  temp_name = "#{arm_name}/#{name}.framework/#{name}"
                  return File.join(filepath,temp_name) # TYSecKit.xcframework/ios-arm64_armv7/TYSecKit.framework/TYSecKit
                end
              end
            end
          end
          # 兼容作者代码,默认取.a文件
          lib_name = "lib#{name}.a"
          lib_path = File.join(dir,lib_name)

          unless File.exist?(lib_path)
            lib_path = File.join(dir.children.first,lib_name)
          end

          lib_path
        end

        #源码地址
        # def get_gitlib_iOS_path(name)
        #   "git@gitlab.xxx.com:iOS/#{name}.git"
        # end
        #要转换的地址，Github-iOS默认都是静态库
        # def git_gitlib_iOS_path
        #   'git@gitlab.xxx.com:Github-iOS/'
        # end


        #要转换的地址，Github-iOS默认都是静态库
        # def http_gitlib_GitHub_iOS_path
        #   'https://gitlab.xxx.com/Github-iOS/'
        # end

        #要转换的地址，iOS默认都是静态库
        # def http_gitlib_iOS_path
        #   'https://gitlab.xxx.com/iOS/'
        # end

        #==========================list begin ==============

        def list
          Dir.entries(source_root).each do |sub|
            UI.puts "- #{sub}" unless sub.include?('.')
          end
          UI.puts "加载完成"
        end


        #==========================clean begin ==============
        def all_clean
          FileUtils.rm_rf(source_root) if File.directory?(source_root)
          UI.puts "清理完成 #{source_root}"
        end

        def clean
          raise "请输入要删除的组件库" if @names.nil?
          @names.each do  |name|
            full_path = File.join(source_root,name)
            if File.directory?(full_path)
              FileUtils.rm_rf(full_path)
            else
              UI.puts "找不到 #{full_path}".yellow
            end
          end
          UI.puts "清理完成 #{@names.to_s}"
        end

        private

        def source_root
          dir = File.join(@config.cache_root,"Source")
          FileUtils.mkdir_p(dir) unless File.exist? dir
          dir
        end

      end
    end
  end
end
