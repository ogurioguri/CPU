#include "io.h"
// Target: Simulate a Bulgarian-solitaire game.
// Possible opitimization: Dead code elimination, common expression, inline function, loop unrolling, etc.
// REMARKS: A funny game. If you like, you can try to prove that when n=1+2+..+i(i>0), the game will always stop
//          and converge to the only solution: {1,2,...i}.   :)

int n;
int h;

int pd(int x) {
    for (;h <= x; ++h)
        if (x == h * (h + 1) / 2)
			return 1;
    return 0;
}

int main() {
	n = 210;
    if (!pd(n)) {
        println("1");
        return 1;
    }
    return 0;
}
