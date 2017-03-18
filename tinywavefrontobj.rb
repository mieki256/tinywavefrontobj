#!ruby -Ku
# -*- mode: ruby; coding: utf-8 -*-
# Last updated: <2017/03/17 21:03:32 +0900>
#
# wavefront(.obj) read, parse and dump
#
# usage :
#   ruby wavefrontobj.rb INFILE.obj [options]
#   ruby wavefrontobj.rb --help
#
# testing environment : Ruby 2.2.6 p396 mingw32
# License : CC0 / Public Domain

Version = "1.0.2"

require 'pp'
require 'json'
require 'yaml'

# wavefront(.obj) read, parse and dump class
class TinyWaveFrontObj

  # @return [String] .obj file path
  attr_reader :objpath

  # @return [String] Directory where .obj is stored
  attr_reader :objdir

  # @return [String] .mtl filename (material file)
  attr_reader :material_filename

  # @return [Array<Array>] vertex (x, y, z, w)
  attr_reader :vertexs

  # @return [Array<Array>] uv (u, v, w)
  attr_reader :uvs

  # @return [Array<Array>] normal (x, y, z)
  attr_reader :normals

  # @return [Array<Array>] vp ( u or u, v or u, v, w)
  attr_reader :vps

  # @return [Hash<Array>] face
  attr_reader :faces

  # @return [Hash] material
  attr_reader :mtls

  # @return [Array] textures
  attr_reader :texs

  # @return [Hash] vertex array data
  attr_reader :vertex_array_data

  # @return [true, false] use vertex
  attr_reader :use_vertex

  # @return [true, false] use normal
  attr_reader :use_normal

  # @return [true, false] use uv (texture)
  attr_reader :use_uv

  # @return [true, false] use index (vertex index)
  attr_accessor :use_index

  # @return [true, false] use color array
  attr_accessor :use_color

  # initialize
  #
  # @param objpath [String] .obj path
  # @param use_varray [true, false] use vertex array
  # @param use_index [true, false] use vertex index
  # @param use_color [true, false] use color array
  # @param vflip [true, false] v flip of u,v
  # @param hexcolor [true, false] color code 0xAARRGGBB
  # @param xyzmul [Array<Float>] x,y,z flip
  def initialize(objpath,
                 use_varray: true,
                 use_index: true,
                 use_color: false,
                 vflip: true,
                 hexcolor: false,
                 xyzmul: [1.0, 1.0, 1.0])

    @objpath = File.expand_path(objpath)
    @use_varray = use_varray
    @use_index = use_index
    @use_color = use_color
    @vflip = vflip
    @hexcolor = hexcolor
    @xyzmul = xyzmul

    @objdir = File.dirname(@objpath)
    @mtlname = ""
    @vertexs = []
    @uvs = []
    @normals = []
    @vps = []
    @faces = {}
    @mtls = {}
    @texs = []
    @vertex_array_data = {}
    @use_vertex = false
    @use_normal = false
    @use_uv = false

    read_geometry(@objpath)

    @mtlpath = File.join(@objdir, @mtlname)
    read_material(@mtlpath)
    @texs = get_texture_list

    if use_varray
      make_varray_data
    end
  end

  def read_geometry(objpath)
    dbg = false
    mat = "none"
    smooth = false
    objgroup = ""
    File.open(objpath) do |file|
      file.each_line do |l|
        next if l =~ /^#/
        next if l =~ /^$/

        s = l.split(" ")
        case s[0]
        when "mtllib"
          @mtlname = s[1]
          puts ".mtl = #{@mtlname}" if dbg
        when "o"
          objgroup = s[1]
          puts "objgroup #{objgroup}" if dbg
        when "v"
          # vertex
          if s.size == 4
            x, y, z, w = s[1].to_f, s[2].to_f, s[3].to_f, 1.0
            @vertexs.push([x, y, z, w])
          elsif s.size == 5
            x, y, z, w = s[1].to_f, s[2].to_f, s[3].to_f, s[4].to_f
            @vertexs.push([x, y, z, w])
          end
        when "vt"
          # texture u v
          if s.size == 3
            u, v, w = s[1].to_f, s[2].to_f, 0.0
            @uvs.push([u, v, w])
          elsif s.size == 4
            u, v, w = s[1].to_f, s[2].to_f, s[3].to_f
            @uvs.push([u, v, w])
          end
        when "vn"
          # normal
          x, y, z = s[1].to_f, s[2].to_f, s[3].to_f
          @normals.push([x, y, z])
        when "vp"
          if s.size == 2
            u = s[1].to_f
            @vps.push([u])
          elsif s.size == 3
            u, v = s[1].to_f, s[2].to_f
            @vps.push([u, v])
          elsif s.size == 4
            u, v, w = s[1].to_f, s[2].to_f, s[3].to_f
            @vps.push([u, v, w])
          end
        when "usemtl"
          # use material
          mat = s[1]
          puts "material #{mat}" if dbg
          unless @faces.key?(mat)
            @faces[mat] = []
          end
        when "s"
          # Smooth
          if s[1] == "off"
            smooth = false
          else
            smooth = true
          end
          puts "smooth #{smooth}" if dbg
        when "f"
          # face
          finfo = []
          s.each do |n|
            if n =~ %r|^(\d+)/(\d+)/(\d+)$|
              # vertex, uv, normal
              vi, vti, vni = ($1.to_i - 1), ($2.to_i - 1), ($3.to_i - 1)
              finfo.push([vi, vti, vni])
              @use_vertex = true
              @use_uv = true
              @use_normal = true
            elsif n =~ %r|^(\d+)//(\d+)$|
              # vertex, normal
              vi, vti, vni = ($1.to_i - 1), nil, ($2.to_i - 1)
              finfo.push([vi, vti, vni])
              @use_vertex = true
              @use_normal = true
            elsif n =~ %r|^(\d+)/(\d+)$|
              # vertex, uv
              vi, vti, vni = ($1.to_i - 1), ($2.to_i - 1), nil
              finfo.push([vi, vti, vni])
              @use_vertex = true
              @use_uv = true
            elsif n =~ %r|^(\d+)$|
              # vertex only
              vi, vti, vni = ($1.to_i - 1), nil, nil
              finfo.push([vi, vti, vni])
              @use_vertex = true
            end
          end
          unless finfo.empty?
            dt = { :mat => mat, :smooth => smooth, :vertexs => finfo }
            @faces[mat].push(dt)
          end
        end
      end
    end
  end

  def read_material(mtlpath)
    mtlname = ""
    File.open(mtlpath) do |f|
      f.each_line do |l|
        next if l=~ /^#/
        next if l=~ /^$/

        s = l.split(" ")
        case s[0]
        when "newmtl"
          mtlname = s[1]
          @mtls[mtlname] = {}
        when "Ka"
          # Ambient
          r, g, b = s[1].to_f, s[2].to_f, s[3].to_f
          @mtls[mtlname][:ambient] = [r, g, b, 1.0]
        when "Kd"
          # Diffuse
          r, g, b = s[1].to_f, s[2].to_f, s[3].to_f
          @mtls[mtlname][:diffuse] = [r, g, b, 1.0]
        when "Ks"
          # Specular
          r, g, b = s[1].to_f, s[2].to_f, s[3].to_f
          @mtls[mtlname][:specular] = [r, g, b, 1.0]
        when "Ns"
          # Shininess
          @mtls[mtlname][:shininess] = s[1].to_f
        when "Ke"
          # Emission ?
          r, g, b = s[1].to_f, s[2].to_f, s[3].to_f
          @mtls[mtlname][:emission] = [r, g, b, 1.0]
        when "Ni"
          # Optical density
          @mtls[mtlname][:optical_density] = s[1].to_f
        when "d"
          # Dissolve
          @mtls[mtlname][:dissolve] = s[1].to_f
        when "illum"
          # Lighting model
          @mtls[mtlname][:illum] = s[1].to_i
        when "map_Ka"
          # Ambient texture
          @mtls[mtlname][:ambient_tex] = s[1]
        when "map_Kd"
          # Diffuse texture
          @mtls[mtlname][:diffuse_tex] = s[1]
        when "map_Ks"
          # Specular texture
          @mtls[mtlname][:specular_tex] = s[1]
        when "map_Ns"
          # Specular highlight texture
          @mtls[mtlname][:specular_high_tex] = s[1]
        when "map_d"
          # Dissolve texture
          @mtls[mtlname][:dissolve_tex] = s[1]
        when "map_bump"
          # Bump mapping texture
          @mtls[mtlname][:map_bump_tex] = s[1]
        when "bump"
          # Bump mapping texture
          @mtls[mtlname][:bump_tex] = s[1]
        when "disp"
          # Displacement texture
          @mtls[mtlname][:displacement_tex] = s[1]
        when "decal"
          # Stencil decal texture
          @mtls[mtlname][:decal_tex] = s[1]
        end
      end
    end
  end

  # get texture list
  # @return [Array<String>] texture name
  def get_texture_list
    lst = {}
    @mtls.each_value do |mat|
      [
        :ambient_tex,
        :diffuse_tex,
        :specular_tex,
        :specular_high_tex,
        :dissolve_tex,
        :map_bump_tex,
        :bump_tex,
        :displacement_tex,
        :decal_tex
      ].each do |k|
        lst[mat[k]] = 1 if mat.key?(k)
      end
    end
    return lst.keys
  end

  # make vertex array data
  #
  # @param face [true, false] create data and overwrite
  def make_varray_data(force = false)
    if @vertex_array_data.empty? or force
      if @use_index
        make_varray_with_index(@vflip)
      else
        make_varray_not_with_index(@vflip)
      end
    end
  end

  # make vertex array not with vertex index
  #
  # @param vflip [true, false] flip the v of u, v
  def make_varray_not_with_index(vflip = true)
    vertexs = []
    normals = []
    uvs = []
    colors = []

    @faces.each do |mtlname, value|
      r, g, b = @mtls[mtlname][:diffuse]
      col = [r, g, b]
      value.each do |face|
        finfo = [] # !> assigned but unused variable - finfo
        face[:vertexs].each do |vi, vti, vni|
          x, y, z, _ = @vertexs[vi]
          x *= @xyzmul[0]
          y *= @xyzmul[1]
          z *= @xyzmul[2]
          vertexs.push([x, y, z])

          nx, ny, nz = 0.0, 0.0, 0.0
          if vni
            nx, ny, nz, _ = @normals[vni]
            nx *= @xyzmul[0]
            ny *= @xyzmul[1]
            nz *= @xyzmul[2]
          end
          normals.push([nx, ny, nz])

          u, v = 0.0, 0.0
          if vti
            u, v, _ = @uvs[vti]
            v = 1.0 - v if vflip
          end
          uvs.push([u, v])

          colors.push(col)
        end
      end
    end

    @vertex_array_data = {
      :vertex => vertexs,
      :normal => normals,
      :uv => uvs,
      :color => colors,
    }
  end

  # make vertex array with vertex index
  #
  # @param vflip [true, false] flip the v of u, v
  def make_varray_with_index(vflip = true)
    vertexs = []
    normals = []
    uvs = []
    colors = []
    faces = []

    cnt = 0
    @faces.each do |mtlname, value|
      r, g, b = @mtls[mtlname][:diffuse]
      col = [r, g, b]
      value.each do |face|
        finfo = []
        face[:vertexs].each do |vi, vti, vni|

          x, y, z = 0.0, 0.0, 0.0
          if vi
            x, y, z, _ = @vertexs[vi]
            x *= @xyzmul[0]
            y *= @xyzmul[1]
            z *= @xyzmul[2]
          end
          xyz = [x, y, z]

          nx, ny, nz = 0.0, 0.0, 0.0
          if vni
            nx, ny, nz, _ = @normals[vni]
            nx *= @xyzmul[0]
            ny *= @xyzmul[1]
            nz *= @xyzmul[2]
          end
          nxyz = [nx, ny, nz]

          u, v = 0.0, 0.0
          if vti
            u, v, _ = @uvs[vti]
            v = 1.0 - v if vflip
          end
          uv = [u, v]

          find_idx = nil
          if vertexs.include?(xyz)
            idx = vertexs.index(xyz)
            if uvs[idx] == uv and normals[idx] == nxyz and colors[idx] == col
              find_idx = idx
            end
          end

          if find_idx != nil
            finfo.push(find_idx)
          else
            vertexs.push(xyz)
            uvs.push(uv)
            normals.push(nxyz)
            colors.push(col)
            finfo.push(cnt)
            cnt += 1
          end
        end
        faces.push(finfo)
      end
    end

    @vertex_array_data = {
      :vertex => vertexs,
      :normal => normals,
      :uv => uvs,
      :color => colors,
      :face => faces,
    }
  end

  # get vertex array
  # @return [Array<Float>] vertex array
  def get_vertex_array
    return nil unless @use_vertex
    make_varray_data
    return @vertex_array_data[:vertex].flatten
  end

  # get normal array
  # @return [Array<Float>] normal array
  def get_normal_array
    return nil unless @use_normal
    make_varray_data
    return @vertex_array_data[:normal].flatten
  end

  # get uv array
  # @return [Array<Float>] uv array
  def get_uv_array
    return nil unless @use_uv
    make_varray_data
    return @vertex_array_data[:uv].flatten
  end

  # get color array
  # @return [Array<Float>] color array
  def get_color_array
    return nil unless @use_color
    make_varray_data
    return get_hexcolor_array if @hexcolor
    return @vertex_array_data[:color].flatten
  end

  def get_hexcolor_array
    cols = []
    @vertex_array_data[:color].each do |r, g, b|
      cols.push(get_hexcolor(r, g, b, 1.0))
    end
    return cols
  end

  def iclamp(v, minv, maxv)
    return minv if v < minv
    return maxv if v > maxv
    return v
  end

  def get_hexcolor(r, g, b, a)
    a = iclamp((255 * a).to_i, 0, 255)
    r = iclamp((255 * r).to_i, 0, 255)
    g = iclamp((255 * g).to_i, 0, 255)
    b = iclamp((255 * b).to_i, 0, 255)
    return ((a << 24) + (r << 16) + (g << 8) + b)
  end

  # get face (vertex index) array
  # @return [Array<Integer>] face (vertex index) array
  def get_face_array
    return nil unless @use_index
    make_varray_data
    return @vertex_array_data[:face].flatten
  end

  def dump_info_size
    puts "\# vertex = #{@vertexs.size}"
    puts "\# uv     = #{@uvs.size}"
    puts "\# normal = #{@normals.size}"

    cnt = 0
    @faces.each { |k, v| cnt += v.size }
    puts "\# face   = #{cnt}"
    puts "\# material = #{@faces.size}"
    puts
  end

  def dump_faces
    puts "\# " + ('-' * 40)
    puts "\# Face"
    puts
    @faces.each do |key, value|
      puts "material : #{key}"
      value.each_with_index do |f, i|
        puts "face #{i} : "
        pp f
      end
    end
    puts
  end

  def dump_mtl
    puts "\# " + ('-' * 40)
    puts "\# Material"
    puts
    @mtls.each do |key, value|
      puts "#{key} :"
      pp value
    end
    puts
  end

  def dump_texs
    puts "\# " + ('-' * 40)
    puts "\# Texture image list"
    puts
    @texs.each { |tn| puts tn }
    puts
  end

  def dump_vertex_array(use_format = "raw")
    make_varray_data
    case use_format
    when "json"
      puts get_vertex_array_json
    when "yaml"
      puts get_vertex_array_yaml
    else
      puts get_vertex_array_raw
    end
  end

  def get_vertex_array_json(pretty = false)
    dt = get_vertex_array_data
    return ((pretty)? JSON.pretty_generate(dt) : JSON.generate(dt))
  end

  def get_vertex_array_yaml
    dt = get_vertex_array_data
    return dt.to_yaml
  end

  def get_vertex_array_data
    dt = {}
    dt["vertex"] = get_vertex_array
    dt["normal"] = get_normal_array if @use_normal
    dt["uv"] = get_uv_array if @use_uv
    if @use_color
      if @hexcolor
        dt["color"] = get_hexcolor_array
      else
        dt["color"] = get_color_array
      end
    end
    dt["face"] = get_face_array if @use_index
    return dt
  end

  def get_vertex_array_raw
    s = []
    s.push("@vertexes = [")
    s.push("  \# x, y, z")
    @vertex_array_data[:vertex].each_with_index do |xyz, i|
      x, y, z = xyz
      s.push("  #{x}, #{y}, #{z},  \# #{i}")
    end
    s.push("]")
    s.push("")

    if @use_normal
      s.push("@normals = [")
      s.push("  \# x, y, z")
      @vertex_array_data[:normal].each_with_index do |nxyz, i|
        nx, ny, nz = nxyz
        s.push("  #{nx}, #{ny}, #{nz},  \# #{i}")
      end
      s.push("]")
      s.push("")
    end

    if @use_uv
      s.push("@uvs = [")
      s.push("  \# u, v")
      @vertex_array_data[:uv].each_with_index do |uv, i|
        u, v = uv
        s.push("  #{u}, #{v},  \# #{i}")
      end
      s.push("]")
      s.push("")
    end

    if @use_color
      s.push("@colors = [")
      s.push("  \# r, g, b, a")
      if @hexcolor
        @vertex_array_data[:color].each_with_index do |col, i|
          r, g, b = col
          c = sprintf("0x%08x", get_hexcolor(r, g, b, 1.0))
          s.push("  #{c},  \# #{i}")
        end
      else
        @vertex_array_data[:color].each_with_index do |col, i|
          r, g, b = col
          s.push("  #{r}, #{g}, #{b}, 1.0,  \# #{i}")
        end
      end
      s.push("]")
      s.push("")
    end

    if @use_index
      s.push("@faces = [")
      @vertex_array_data[:face].each_with_index do |finfo, i|
        l = ""
        finfo.each { |idx| l += "#{idx}, " }
        l.strip!
        s.push("  #{l}  \# #{i}")
      end
      s.push("]")
    end

    return s.join("\n")
  end

  def self.parse_options(argv)
    require 'optparse'

    opts = {
      :index => true,
      :xflip => false,
      :yflip => false,
      :zflip => false,
      :vflip => true,
      :color => false,
      :hexcolor => false,
      :json => false,
      :yaml => false,
      :varray => true,
      :dxruby => false,
      :debug => false,
    }

    OptionParser.new do |opt|
      opt.banner = "Usage : ruby #{$0} INFILE.obj [options]"
      opt.on("--no-index", "not use vertex index") { |v| opts[:index] = v }
      opt.on("-x", "--xflip", "x flip") { |v| opts[:xflip] = v }
      opt.on("-y", "--yflip", "y flip") { |v| opts[:yflip] = v }
      opt.on("-z", "--zflip", "z flip") { |v| opts[:zflip] = v }
      opt.on("--[no-]vflip", "v flip") { |v| opts[:vflip] = v }
      opt.on("--[no-]color", "add diffuse color array") { |v| opts[:color] = v }
      opt.on("--hexcolor", "color code 0xAARRGGBB") { |v| opts[:hexcolor] = v }
      opt.on("--json", "output json format") { |v| opts[:json] = v }
      opt.on("--yaml", "output YAML format") { |v| opts[:yaml] = v }
      opt.on("--no-varray", "not use vertex array") { |v| opts[:varray] = v }
      opt.on("--dxruby", "set --no-index --zflip --hexcolor") { |v| opts[:dxruby] = v }
      opt.on("--debug", "dump .obj information") { |v| opts[:debug] = v }

      begin
        opt.parse!(argv)
      rescue
        abort "Invalid option. \n#{opt}"
      end

      unless argv.empty?
        if argv[0] =~ /\.obj$/i
          opts[:infile] = argv.shift
        end
        abort "Invalid option. \n#{opt}" unless argv.empty?
      end

      abort "Not found .obj file. \n#{opt}" unless opts.key?(:infile)

      if opts[:dxruby]
        opts[:index] = false
        opts[:zflip] = true
        opts[:hexcolor] = true
      end

      xyzmul = [
        ((opts[:xflip])? -1.0 : 1.0),
        ((opts[:yflip])? -1.0 : 1.0),
        ((opts[:zflip])? -1.0 : 1.0),
      ]
      opts[:xyzmul] = xyzmul

      return opts
    end
  end

end

# ----------------------------------------
if $0 == __FILE__

  opts = TinyWaveFrontObj.parse_options(ARGV)

  o = TinyWaveFrontObj.new(opts[:infile],
                           use_varray: opts[:varray],
                           use_index: opts[:index],
                           use_color: opts[:color],
                           vflip: opts[:vflip],
                           hexcolor: opts[:hexcolor],
                           xyzmul: opts[:xyzmul])

  if opts[:debug]
    o.dump_info_size
    o.dump_faces
    o.dump_mtl
    o.dump_texs
  else
    if opts[:varray]
      fmt = "raw"
      fmt = "json" if opts[:json]
      fmt = "yaml" if opts[:yaml]
      o.dump_vertex_array(fmt)
    end
  end
end
