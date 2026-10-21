#include <stdio.h>
#include <stdlib.h>

#define N 100000

int numbers[N];
char seen[200000];

int main(void)
{
    srand(42);
    for (int i = 0; i < N; i++)
        numbers[i] = rand() % 200000;

    FILE *f = fopen("v3.bin", "w");
    for (int i = 0; i < N; i++) {
        if (!seen[numbers[i]]) {
            seen[numbers[i]] = 1;
            fwrite(&numbers[i], sizeof(int), 1, f);
        }
    }
    fclose(f);
    return 0;
}
