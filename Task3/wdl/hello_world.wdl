version 1.0

workflow HelloWorld {
  input {
    String name = "bioinformatics"
  }

  call SayHello {
    input:
      name = name
  }

  output {
    String greeting = SayHello.message
  }
}

task SayHello {
  input {
    String name
  }

  command <<<
    echo "Hello, ~{name}! WDL pipeline works."
  >>>

  output {
    String message = read_string(stdout())
  }
}
