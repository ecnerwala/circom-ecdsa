pragma circom 2.0.1;

include "../node_modules/circomlib/circuits/comparators.circom";
include "../node_modules/circuits/bitify.circom";

include "bigint_func.circom";

// addition mod 2**n with carry bit
template ModSum(n) {
    assert(n <= 252);
    signal input a;
    signal input b;
    signal output sum;
    signal output carry;

    component n2b = Num2Bits(n + 1);
    n2b.in <== a + b;
    carry <== n2b.out[n];
    sum <== a + b - carry * (1 << n);
}

template ModSub(n) {
    assert(n <= 252);
    signal input a;
    signal input b;
    signal output out;
    signal output borrow;
    component lt = LessThan(n);
    lt.in[0] <== a;
    lt.in[1] <== b;
    borrow <== lt.out;
    out <== borrow * (1<<n) + a - b;
}

// a - b - c
template ModSubThree(n) {
    assert(n + 2 <= 253);
    signal input a;
    signal input b;
    signal input c; 
    signal output out;
    signal output borrow;
    signal tmp;
    tmp <== b+c;
    component lt = LessThan(n + 1);
    lt.in[0] <== a;
    lt.in[1] <== tmp;
    borrow <== lt.out;
    out <== borrow*(1<<n) + a - tmp;
}

template ModSumThree(n) {
    assert(n + 2 <= 253);
    signal input a;
    signal input b;
    signal input c; 
    signal output sum;
    signal output carry;

    component n2b = Num2Bits(n + 2);
    n2b.in <== a + b + c;
    carry <== n2b.out[n] + 2 * n2b.out[n + 1];
    sum <== a + b + c - carry * (1 << n);
}

template ModSumFour(n) {
    assert(n + 2 <= 253);
    signal input a;
    signal input b;
    signal input c;
    signal input d;         
    signal output sum;
    signal output carry;

    component n2b = Num2Bits(n + 2);
    n2b.in <== a + b + c + d;
    carry <== n2b.out[n] + 2 * n2b.out[n + 1];
    sum <== a + b + c + d - carry * (1 << n);
}

// product mod 2**n with carry
template ModProd(n) {
    assert(n <= 126);
    signal input a;
    signal input b;
    signal output prod;
    signal output carry;

    component n2b = Num2Bits(2 * n);
    n2b.in <== a * b;

    component b2n1 = Bits2Num(n);
    component b2n2 = Bits2Num(n);
    var i;
    for (i = 0; i < n; i++) {
        b2n1.in[i] <== n2b.out[i];
        b2n2.in[i] <== n2b.out[i + n];
    }
    prod <== b2n1.out;
    carry <== b2n2.out;
}

// split a n + m bit input into two outputs
template Split(n, m) {
    assert(n <= 126);
    signal input in;
    signal output small;
    signal output big;    

    small <-- in % (1 << n);
    big <-- in \ (1 << n);

    component n2b_small = Num2Bits(n);
    n2b_small.in <== small;
    component n2b_big = Num2Bits(m);
    n2b_big.in <== big;

    in === small + big * (1 << n);
}

// split a n + m + k bit input into three outputs
template SplitThree(n, m, k) {
    assert(n <= 126);
    signal input in;
    signal output small;
    signal output medium;
    signal output big;      

    small <-- in % (1 << n);
    medium <-- (in \ (1 << n)) % (1 << m);
    big <-- in \ (1 << n + m);

    component n2b_small = Num2Bits(n);
    n2b_small.in <== small;
    component n2b_medium = Num2Bits(m);
    n2b_medium.in <== medium;
    component n2b_big = Num2Bits(k);
    n2b_big.in <== big;

    in === small + medium * (1 << n) + big * (1 << n + m);
}

// a[i], b[i] in 0... 2**n-1
// represent a = a[0] + a[1] * 2**n + .. + a[k - 1] * 2**(n * k)
template BigAdd(n, k) {
    assert(n <= 252);
    signal input a[k];
    signal input b[k];
    signal output out[k + 1];

    component unit0 = ModSum(n);
    unit0.a <== a[0];
    unit0.b <== b[0];
    out[0] <== unit0.sum;

    component unit[k - 1];
    for (var i = 1; i < k; i++) {
        unit[i - 1] = ModSumThree(n);
        unit[i - 1].a <== a[i];
        unit[i - 1].b <== b[i];
        if (i == 1) {
            unit[i - 1].c <== unit0.carry;
        } else {
            unit[i - 1].c <== unit[i - 2].carry;
        }
        out[i] <== unit[i - 1].sum;
    }
    out[k] <== unit[k - 2].carry;
}

// a[i] and b[i] are short unsigned integers
// out[i] is a long unsigned integer
template BigMultShortLong(n, k) {
   assert(n <= 126);
   signal input a[k];
   signal input b[k];
   signal output out[2 * k - 1];

   var prod_val[2 * k - 1];
   for (var i = 0; i < 2 * k - 1; i++) {
       prod_val[i] = 0;
       if (i < k) {
           for (var a_idx = 0; a_idx <= i; a_idx++) {
               prod_val[i] = prod_val[i] + a[a_idx] * b[i - a_idx];
           }
       } else {
           for (var a_idx = i - k + 1; a_idx < k; a_idx++) {
               prod_val[i] = prod_val[i] + a[a_idx] * b[i - a_idx];
           }
       }
       out[i] <-- prod_val[i];
   }

   var a_poly[2 * k - 1];
   var b_poly[2 * k - 1];
   var out_poly[2 * k - 1];
   for (var i = 0; i < 2 * k - 1; i++) {
       out_poly[i] = 0;
       a_poly[i] = 0;
       b_poly[i] = 0;    
       for (var j = 0; j < 2 * k - 1; j++) {
           out_poly[i] = out_poly[i] + out[j] * (i ** j);
       }
       for (var j = 0; j < k; j++) {
           a_poly[i] = a_poly[i] + a[j] * (i ** j);
           b_poly[i] = b_poly[i] + b[j] * (i ** j);
       }
   }
   for (var i = 0; i < 2 * k - 1; i++) {
      out_poly[i] === a_poly[i] * b_poly[i];
   }
}


// in[i] contains longs
// out[i] contains shorts
template LongToShortNoEndCarry(n, k) {
    assert(n <= 126);
    signal input in[k];
    signal output out[k + 1];

    component splits[k];
    for (var i = 0; i < k; i++) {
        splits[i] = SplitThree(n, n, log_ceil(k));
        splits[i].in <== in[i];
    }

    out[0] <== splits[0].small;

    component adder1 = ModSum(n);
    adder1.a <== splits[1].small;
    adder1.b <== splits[0].medium;
    out[1] <== adder1.sum;

    component adders[k - 2];    
    for (var i = 2; i < k; i++) {
        adders[i - 2] = ModSumFour(n);
        adders[i - 2].a <== splits[i].small;
        adders[i - 2].b <== splits[i - 1].medium;
        adders[i - 2].c <== splits[i - 2].big;        
        if (i == 2) {
            adders[i - 2].d <== adder1.carry;
        } else {
            adders[i - 2].d <== adders[i - 3].carry;
        }
        out[i] <== adders[i - 2].sum;
    }
    if (k >= 3) {
        out[k] <== splits[k - 2].big + splits[k - 1].medium + adders[k - 3].carry;
    } else {
        if (k >= 2) {
            out[k] <== splits[k - 2].big + splits[k - 1].medium;
        } else {
            out[k] <== splits[k - 1].medium;
        }
    }
}

template BigMult(n, k) {
    signal input a[k];
    signal input b[k];
    signal output out[2 * k];

    component mult = BigMultShortLong(n, k);
    for (var i = 0; i < k; i++) {
        mult.a[i] <== a[i];
        mult.b[i] <== b[i];
    }

    // no carry is possible in the highest order register
    component longshort = LongToShortNoEndCarry(n, 2 * k - 1);
    for (var i = 0; i < 2 * k - 1; i++) {
        longshort.in[i] <== mult.out[i];
    }
    for (var i = 0; i < 2 * k; i++) {
        out[i] <== longshort.out[i];
    }
}

template BigLessThan(n, k){
    signal input a[k];
    signal input b[k];
    signal output out;

    component lt[k];
    component eq[k];
    for (var i = 0; i < k; i++) {
        lt[i] = LessThan(n);
        lt[i].in[0] <== a[i];
        lt[i].in[1] <== b[i];
        eq[i] = IsEqual();
        eq[i].in[0] <== a[i];
        eq[i].in[1] <== b[i];
    }

    // ors[i] holds (lt[k - 1] || (eq[k - 1] && lt[k - 2]) .. || (eq[k - 1] && .. && lt[i]))
    // ands[i] holds (eq[k - 1] && .. && lt[i])
    // eq_ands[i] holds (eq[k - 1] && .. && eq[i])
    component ors[k - 1];
    component ands[k - 1];
    component eq_ands[k - 1];          
    for (var i = k - 2; i >= 0; i--) {
        ands[i] = AND();
        eq_ands[i] = AND();
        ors[i] = OR();           

        if (i == k - 2) {
           ands[i].a <== eq[k - 1].out;
           ands[i].b <== lt[k - 2].out;
           eq_ands[i].a <== eq[k - 1].out;
           eq_ands[i].b <== eq[k - 2].out;
           ors[i].a <== lt[k - 1].out;
           ors[i].b <== ands[i].out;
        } else {
           ands[i].a <== eq_ands[i + 1].out;
           ands[i].b <== lt[i].out;
           eq_ands[i].a <== eq_ands[i + 1].out;
           eq_ands[i].b <== eq[i].out;
           ors[i].a <== ors[i + 1].out;
           ors[i].b <== ands[i].out;
        }
     }
     out <== ors[0].out;
}

function vlog(verbose, x) {
    if (verbose == 1) {
        log(x);
    }
    return x;
}

// leading register of b should be non-zero
template BigMod(n, k) {
    assert(n <= 126);
    signal input a[2 * k];
    signal input b[k];

    signal output div[k + 1];
    signal output mod[k];

    var longdiv[2][100] = long_div(n, k, a, b);
    for (var i = 0; i < k; i++) {
        div[i] <-- longdiv[0][i];
        mod[i] <-- longdiv[1][i];
    }
    div[k] <-- longdiv[0][k];

    component mul = BigMult(n, k + 1);
    for (var i = 0; i < k; i++) {
        mul.a[i] <== div[i];
        mul.b[i] <== b[i];
    }
    mul.a[k] <== div[k];
    mul.b[k] <== 0;

    for (var i = 0; i < 2 * k + 2; i++) {
        //log(mul.out[i]);
    }

    component add = BigAdd(n, 2 * k + 2);
    for (var i = 0; i < 2 * k; i++) {
        add.a[i] <== mul.out[i];
        if (i < k) {
            add.b[i] <== mod[i];
        } else {
            add.b[i] <== 0;
        }
    }
    add.a[2 * k] <== mul.out[2 * k];
    add.a[2 * k + 1] <== mul.out[2 * k + 1];        
    add.b[2 * k] <== 0;
    add.b[2 * k + 1] <== 0;

    for (var i = 0; i < 2 * k + 2; i++) {
        //log(add.out[i]);
    }

    for (var i = 0; i < 2 * k; i++) {
        add.out[i] === a[i];
    }
    add.out[2 * k] === 0;
    add.out[2 * k + 1] === 0;   

    component lt = BigLessThan(n, k);
    for (var i = 0; i < k; i++) {
        lt.a[i] <== mod[i];
        lt.b[i] <== b[i];
    }
    lt.out === 1;
}

// a[i], b[i] in 0... 2**n-1
// represent a = a[0] + a[1] * 2**n + .. + a[k - 1] * 2**(n * k)
// assume a >= b
template BigSub(n, k) {
    assert(n <= 252);
    signal input a[k];
    signal input b[k];
    signal output out[k];
    signal output underflow;

    component unit0 = ModSub(n);
    unit0.a <== a[0];
    unit0.b <== b[0];
    out[0] <== unit0.out;

    component unit[k - 1];
    for (var i = 1; i < k; i++) {
        unit[i - 1] = ModSubThree(n);
        unit[i - 1].a <== a[i];
        unit[i - 1].b <== b[i];
        if (i == 1) {
            unit[i - 1].c <== unit0.borrow;
        } else {
            unit[i - 1].c <== unit[i - 2].borrow;
        }
        out[i] <== unit[i - 1].out;
    }
    underflow <== unit[k - 2].borrow;
}

template BigSubModP(n, k){
    assert (n<= 252);
    signal input a[k];
    signal input b[k];
    signal input p[k];
    signal output out[k];
    component sub = BigSub(n, k);
    for (var i = 0; i < k; i++){
        sub.a[i] <== a[i];
        sub.b[i] <== b[i];
    }
    signal flag;
    flag <== sub.underflow;
    component add = BigAdd(n, k);
    for (var i = 0; i < k; i++){
        add.a[i] <== sub.out[i];
        add.b[i] <== p[i];
    }
    signal tmp[k];
    for (var i = 0; i < k; i++){
        tmp[i] <== (1-flag) * sub.out[i];
        out[i] <==  tmp[i] + flag * add.out[i];
    }
}