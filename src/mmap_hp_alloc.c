/* Mapping and allocating 2 HugePages of 1G 
 * https://www.kernel.org/doc/Documentation/vm/hugetlbpage.txt
 * https://www.kernel.org/doc/Documentation/vm/numa_memory_policy.txt
 * */

#include <sys/mman.h>
#include <stdio.h>
#include <stdlib.h>

#define PAGE_SIZE (unsigned int) 1024*1024*1024
#define NUM_PAGES 1

void main() {
		char * buf = mmap(
				NULL, 
				NUM_PAGES * PAGE_SIZE,
				PROT_READ | PROT_WRITE, 
				MAP_PRIVATE | MAP_ANONYMOUS | MAP_HUGETLB | MAP_POPULATE,
				-1, 
				0
		); 
		if (buf == MAP_FAILED) {
				perror("mmap");
				exit(1);
		}

		char * line = NULL;
		size_t size;
		getline(&line,&size,stdin);
}
