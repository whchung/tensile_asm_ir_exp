ASM=/opt/rocm/hcc/bin/llvm-mc
INPUT=Cij_Aik_Bjk_SB_MT128x128x08_K1.s
OUTPUT=tensile.o
TARGET=gfx900

all:
	$(ASM) -arch amdgcn -mcpu $(TARGET) $(INPUT) -o $(OUTPUT)

clean:
	@rm -f $(OUTPUT)
