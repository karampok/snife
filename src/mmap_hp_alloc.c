/* Mapping and allocating 2 HugePages of 1G 
 * https://www.kernel.org/doc/Documentation/vm/hugetlbpage.txt
 * https://www.kernel.org/doc/Documentation/vm/numa_memory_policy.txt
 * https://mazzo.li/posts/check-huge-page.html
 * https://github.com/torvalds/linux/blob/master/tools/testing/selftests/vm/hugepage-mmap.c
 * */


/* int main(int argc, char* argv[]) */
/* { */
/* 	size_t size; */

/*   if (argc != 2) { */
/* 		printf("Usage: %s  <size (GiB)>\n", */
/* 				argv[0]); */
/* 		exit(1); */
/* 	} */

/* 	size = atoi(argv[1]) * HPAGE_SIZE; */

/*   printf("all good, exiting\n"); */
/*   return 0; */
/* } */

/* Mapping and allocating 2 HugePages of 1G */

#include <sys/mman.h>
#include <stdio.h>
#include <stdlib.h>

#define PAGE_SIZE (unsigned int) 1024*1024*1024
#define NUM_PAGES 6

void main(int argc, char* argv[]){
  /* if (argc != 2) { */
		/* printf("Usage: %s  <size (GiB)>\n", */
				/* argv[0]); */
		/* exit(1); */
	/* } */

	/* uint num = atoi(argv[1]); */


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
