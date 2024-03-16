import random

MEM_SIZE = 2 ** 14
# MEM_SIZE = 0x6000

def main():
    mem = [random.randint(0, 2 ** 32) for _ in range(MEM_SIZE)]
    with open("rtl/otter_mem.mem", "w") as f:
        for i in mem:
            f.write(hex(i)[2:]+ "\n")
        
    
    
    
    
if __name__ == "__main__":
    main()