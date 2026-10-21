#include <fcntl.h>
#include <stdlib.h>
#include <unistd.h>

#define N 100000

int numbers[N];
char seen[200000];

int main(void)
{
    srand(42);
    for (int i = 0; i < N; i++)
        numbers[i] = rand() % 200000;

    int fd = open("v2.bin", O_WRONLY | O_CREAT | O_TRUNC, 0644);
    for (int i = 0; i < N; i++) {
        if (!seen[numbers[i]]) {
            seen[numbers[i]] = 1;
            write(fd, &numbers[i], sizeof(int));
        }
    }
    close(fd);
    return 0;
}
