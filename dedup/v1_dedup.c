#include <fcntl.h>
#include <stdlib.h>
#include <unistd.h>

#define N 100000

int numbers[N];

int main(void)
{
    srand(42);
    for (int i = 0; i < N; i++)
        numbers[i] = rand() % 200000;

    int fd = open("v1.bin", O_WRONLY | O_CREAT | O_TRUNC, 0644);
    for (int i = 0; i < N; i++) {
        int j;
        for (j = 0; j < i; j++)
            if (numbers[j] == numbers[i])
                break;
        if (j == i)
            write(fd, &numbers[i], sizeof(int));
    }
    close(fd);
    return 0;
}
