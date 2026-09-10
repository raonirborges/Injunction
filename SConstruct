import os

env = Environment()

# Garante o uso do Clang no Arch
env["CC"] = "clang"
env["CXX"] = "clang++"

# Flags de compilação
env.Append(CCFLAGS=["-fPIC", "-std=c++17", "-O3"])

# Inclui TODOS os caminhos de cabeçalho necessários do godot-cpp
env.Append(CPPPATH=[
    "src/",
    "godot-cpp/include",
    "godot-cpp/gen/include",
    "godot-cpp/gdextension",
    "godot-cpp/include/godot_cpp"
])

# Caminho e biblioteca estática do godot-cpp
env.Append(LIBPATH=["godot-cpp/bin"])
env.Append(LIBS=["godot-cpp.linux.template_debug.x86_64"])

# Busca os arquivos fonte do seu projeto
sources = Glob("src/*.cpp")

# Compila o arquivo final .so na pasta bin/
env.SharedLibrary("bin/libfluid_system.so", source=sources)
