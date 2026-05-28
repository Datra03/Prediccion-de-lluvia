module proyecto

using Downloads
using JSON3
using LinearAlgebra
using Dates
using Plots

include("gradiente_con.jl")
using .gradiente_con

export iniciar_proyecto

gr()

# MULTIPLICACION PARALELA


function multiplicacion_paralela(A, B)

    filasA, columnasA = size(A)

    columnasB = size(B,2)

    C = zeros(filasA, columnasB)

    Threads.@threads for i in 1:filasA

        for j in 1:columnasB

            suma = 0.0

            for k in 1:columnasA

                suma += A[i,k] * B[k,j]

            end

            C[i,j] = suma

        end

    end

    return C

end


# PORCENTAJE LLUVIA


function porcentaje_lluvia(valor)

    minimo = 1015.0
    maximo = 4094.0

    porcentaje = ((maximo - valor) /
                 (maximo - minimo)) * 100

    porcentaje = clamp(porcentaje, 0, 100)

    return porcentaje

end


# INTERPRETACION


function interpretar_lluvia(p)

    if p <= 20

        return "SIN LLUVIA"

    elseif p <= 40

        return "POSIBLE LLUVIA"

    elseif p <= 60

        return "LLUVIA LIGERA"

    elseif p <= 80

        return "LLUVIA MODERADA"

    else

        return "LLUVIA FUERTE"

    end

end


# LEER ARCHIVO


function leer_datos_archivo(nombre)

    if !isfile(nombre)

        return zeros(1,5)

    end

    datos = Float64[]

    open(nombre, "r") do io

        for linea in eachline(io)

            linea = strip(linea)

            if isempty(linea)
                continue
            end

            if startswith(linea, "#")
                continue
            end

            valores = parse.(Float64, split(linea))

            append!(datos, valores)

        end

    end

    if length(datos) == 0

        return zeros(1,5)

    end

    matriz = reshape(datos, :, 5)

    return matriz

end


# ENTRENAR MODELO TEMPORAL


function entrenar_modelo(datos, offset)

    if size(datos,1) <= offset + 1

        return NaN

    end

    X = datos[1:end-offset, 1:end-1]

    y = datos[1+offset:end, end]

    m = size(X,1)

    X = hcat(ones(m), X)

    A = multiplicacion_paralela(
        transpose(X),
        X
    )

    b = multiplicacion_paralela(
        transpose(X),
        reshape(y,:,1)
    )

    b = vec(b)

    coef = gradiente_conjugado(A,b)

    ultima = datos[end,1:end-1]

    ultima = vcat(1.0, ultima)

    pred = dot(ultima, coef)

    return pred

end


# PROYECTO PRINCIPAL


function iniciar_proyecto()

    url = "http://172.17.180.41/datos"

    # DATOS TEMPORALES
    temperaturas = Float64[]
    humedades = Float64[]
    presiones = Float64[]
    luces = Float64[]
    lluvias = Float64[]

    historial_lluvia = Float64[]

    pred1_hist = Float64[]
    pred10_hist = Float64[]
    pred30_hist = Float64[]
    pred60_hist = Float64[]

    contador = 0

    # GRAFICA
    
    plt = plot(
        title = "Prediccion temporal de lluvia",
        xlabel = "Muestras",
        ylabel = "Sensor lluvia",
        legend = :topright,
        linewidth = 3,
        size = (1400,700)
    )

    
    println("SISTEMA INICIADO")
    

    while true

        try

            
            # LEER ESP32
            

            response = Downloads.download(url; timeout=10)

            texto = read(response, String)

            datos = JSON3.read(texto)

            temp = Float64(datos.temperatura)

            hum = Float64(datos.humedad)

            press = Float64(datos.presion)

            luz = Float64(datos.luz)

            lluvia = Float64(datos.lluvia)

            
            # GUARDAR
            

            push!(temperaturas, temp)
            push!(humedades, hum)
            push!(presiones, press)
            push!(luces, luz)
            push!(lluvias, lluvia)

            push!(historial_lluvia, lluvia)

            contador += 1

            
            # MOSTRAR DATOS
            

            println("--------------------------------")

            println(
                "T:", temp,
                " H:", hum,
                " P:", press,
                " L:", luz,
                " R:", lluvia
            )

            
            # GUARDAR CADA 60 DATOS
            

            if contador >= 60

                open("datos.dat", "a") do io

                    fecha = Dates.format(
                        now(),
                        "dd/mm/yyyy HH:MM p"
                    )

                    write(io,
                    "\n# =====================================\n")

                    write(io,
                    "# FECHA: $fecha\n")

                    write(io,
                    "# =====================================\n")

                    for i in 1:length(lluvias)

                        write(io,
                        "$(temperaturas[i]) " *
                        "$(humedades[i]) " *
                        "$(presiones[i]) " *
                        "$(luces[i]) " *
                        "$(lluvias[i])\n")

                    end

                end

                
                # LEER HISTORIAL
                

                datos_archivo = leer_datos_archivo(
                    "datos.dat"
                )

                
                # OFFSETS
                

                offset_1 = 12
                offset_10 = 120
                offset_30 = 360
                offset_60 = 720

                
                # PREDICCIONES TEMPORALES
                

                pred_1 = entrenar_modelo(
                    datos_archivo,
                    offset_1
                )

                pred_10 = entrenar_modelo(
                    datos_archivo,
                    offset_10
                )

                pred_30 = entrenar_modelo(
                    datos_archivo,
                    offset_30
                )

                pred_60 = entrenar_modelo(
                    datos_archivo,
                    offset_60
                )

                
                # GUARDAR HISTORIAL
                

                push!(pred1_hist, pred_1)
                push!(pred10_hist, pred_10)
                push!(pred30_hist, pred_30)
                push!(pred60_hist, pred_60)

                
                # PORCENTAJES
                

                p1 = isnan(pred_1) ? 0 :
                    porcentaje_lluvia(pred_1)

                p10 = isnan(pred_10) ? 0 :
                    porcentaje_lluvia(pred_10)

                p30 = isnan(pred_30) ? 0 :
                    porcentaje_lluvia(pred_30)

                p60 = isnan(pred_60) ? 0 :
                    porcentaje_lluvia(pred_60)

                
                # MOSTRAR
                

                println("\n======================================")
                println("PREDICCIONES")
                println("======================================")

                println("\n1 MIN")

                println("Valor: ", pred_1)

                println("Lluvia: ",
                    round(p1,digits=2), "%")

                println("Estado: ",
                    interpretar_lluvia(p1))

                println("\n10 MIN")

                println("Valor: ", pred_10)

                println("Lluvia: ",
                    round(p10,digits=2), "%")

                println("Estado: ",
                    interpretar_lluvia(p10))

                println("\n30 MIN")

                println("Valor: ", pred_30)

                println("Lluvia: ",
                    round(p30,digits=2), "%")

                println("Estado: ",
                    interpretar_lluvia(p30))

                println("\n60 MIN")

                println("Valor: ", pred_60)

                println("Lluvia: ",
                    round(p60,digits=2), "%")

                println("Estado: ",
                    interpretar_lluvia(p60))

                
                # GRAFICA
                

                x_real = 1:length(historial_lluvia)

                plt = plot(
                    x_real,
                    historial_lluvia,

                    label = "Real",
                    color = :blue,
                    linewidth = 3,

                    title = "Prediccion temporal de lluvia",
                    xlabel = "Muestras",
                    ylabel = "Sensor lluvia",

                    size = (1400,700)
                )

                
                # PRED 1
                

                x1 = collect(1:length(pred1_hist))

                plot!(
                    plt,
                    x1 .* 60,
                    pred1_hist,

                    label = "1 min",
                    color = :green,
                    linewidth = 2
                )

                
                # PRED 10
                

                x10 = collect(1:length(pred10_hist))

                plot!(
                    plt,
                    x10 .* 60,
                    pred10_hist,

                    label = "10 min",
                    color = :yellow,
                    linewidth = 2
                )

                
                # PRED 30
                

                x30 = collect(1:length(pred30_hist))

                plot!(
                    plt,
                    x30 .* 60,
                    pred30_hist,

                    label = "30 min",
                    color = :orange,
                    linewidth = 2
                )

                
                # PRED 60
                

                x60 = collect(1:length(pred60_hist))

                plot!(
                    plt,
                    x60 .* 60,
                    pred60_hist,

                    label = "60 min",
                    color = :red,
                    linewidth = 2
                )

                display(plt)

                
                # LIMPIAR
                

                contador = 0

                empty!(temperaturas)
                empty!(humedades)
                empty!(presiones)
                empty!(luces)
                empty!(lluvias)

            end

            
            # ESPERA
            

            sleep(5)

        catch e

            println("\nERROR:")
            println(e)

            sleep(3)

        end

    end

end

end
