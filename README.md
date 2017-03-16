tinywavefrontobj
================

Wavefront形式(.obj)の3Dモデルデータを読み込んでテキスト出力。

Description
-----------

Wavefront形式(.obj)の3Dモデルデータファイルを読み込んで、Rubyから使いやすい形式でテキスト出力します。

3D表示関係の実験用モデルデータを用意する時に使えるんじゃないかなと…。

Usage
-----

### Rubyソース内に書ける形で出力

    ruby tinywavefrontobj.rb sampledata/cube_tri_tex.obj

### jsonもしくはyamlで出力

    ruby tinywavefrontobj.rb sampledata/cube_tri_tex.obj --json

    ruby tinywavefrontobj.rb sampledata/cube_tri_tex.obj --yaml

### 使用可能なオプション

    ruby tinywavefrontobj.rb --help
    Usage : ruby tinywavefrontobj.rb INFILE.obj [options]
            --no-varray                  vertex array disable
            --no-index                   vertex index disable
            --json                       use json format
            --yaml                       use YAML format
            --debug                      dump .obj information

### Rubyソース内で利用して頂点配列等を取得

    require 'tinywavefrontobj'
    ...
    o = TinyWaveFrontObj.new("hoge.obj", true, true)
    vertex_array = o.get_vertex_array
    normal_array = o.get_normal_array
    uv_array     = o.get_uv_array
    face_array   = o.get_face_array
    ...
    if o.use_uv
      puts "use texture"
    end
    
    if o.use_normal
      puts "use normal"
    end

### 出力したjsonを読み込んで利用

    require 'json'
    ...
    vertex_array = nil
    normal_array = nil
    uv_array     = nil
    face_array   = nil
    File.open(JSON_FILE) { |file|
      hash = JSON.load(file)
      vertex_array = hash["vertex"]
      normal_array = hash["normal"] if hash.key?("normal")
      uv_array     = hash["uv"] if hash.key?("uv")
      face_array   = hash["face"]
    }
    ...
    if uv_array
      puts "use texture"
    end
    
    if normal_array
      puts "use normal"
    end

Testing environment
-------------------

Ruby 2.2.6 p396 mingw32 + Windows10 x64

Licence
-------

CCo / Public Domain

Author
------

mieki256
