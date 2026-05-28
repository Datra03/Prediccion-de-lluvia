module gradiente_con

using LinearAlgebra

export gradiente_conjugado

function gradiente_conjugado(A, b)

    n = size(A,1)

    x = zeros(n)

    r = b - A*x

    p = copy(r)

    tolerancia = 1e-6

    max_iteraciones = 1000

    k = 0

    while norm(r) > tolerancia && k < max_iteraciones

        Ap = A*p

        alpha = dot(r,r) / dot(p,Ap)

        x = x + alpha*p

        r_nuevo = r - alpha*Ap

        if norm(r_nuevo) < tolerancia

            r = r_nuevo

            break

        end

        beta = dot(r_nuevo,r_nuevo) / dot(r,r)

        p = r_nuevo + beta*p

        r = r_nuevo

        k += 1

    end

    println("\nIteraciones: ", k)
    println("Error: ", norm(r))

    return x

end

end